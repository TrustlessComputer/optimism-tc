package txmgr

import (
	"context"
	"fmt"
	"golang.org/x/sync/semaphore"
	"math"
	"math/big"
	"strings"
	"sync"
	"time"

	"github.com/ethereum/go-ethereum/core/types"
	"golang.org/x/sync/errgroup"
)

type TxReceipt[T any] struct {
	// ID can be used to identify unique tx receipts within the recept channel
	ID T
	// Receipt result from the transaction send
	Receipt *types.Receipt
	// Err contains any error that occurred during the tx send
	Err error
}

type Queue[T any] struct {
	ctx        context.Context
	txMgr      TxManager
	maxPending uint64
	daTxMgr    TxManager
	groupLock  sync.Mutex
	groupCtx   context.Context
	group      *errgroup.Group

	sem                     *semaphore.Weighted
	daConfirmedReceiptQueue chan TxCandidate
}

// NewQueue creates a new transaction sending Queue, with the following parameters:
//   - maxPending: max number of pending txs at once (0 == no limit)
//   - pendingChanged: called whenever a tx send starts or finishes. The
//     number of currently pending txs is passed as a parameter.
func NewQueue[T any](ctx context.Context, txMgr TxManager, daTxMgr TxManager, maxPending uint64) *Queue[T] {
	if maxPending > math.MaxInt {
		// ensure we don't overflow as errgroup only accepts int; in reality this will never be an issue
		maxPending = math.MaxInt
	}
	q := &Queue[T]{
		ctx:                     ctx,
		txMgr:                   txMgr,
		daTxMgr:                 daTxMgr,
		maxPending:              maxPending,
		sem:                     semaphore.NewWeighted(10),
		daConfirmedReceiptQueue: make(chan TxCandidate),
	}
	go q.SendStep2Routine()
	return q
}

// Wait waits for all pending txs to complete (or fail).
func (q *Queue[T]) Wait() {
	if q.group == nil {
		return
	}
	_ = q.group.Wait()
}

// Send will wait until the number of pending txs is below the max pending,
// and then send the next tx.
//
// The actual tx sending is non-blocking, with the receipt returned on the
// provided receipt channel. If the channel is unbuffered, the goroutine is
// blocked from completing until the channel is read from.
func (q *Queue[T]) Send(id T, candidate TxCandidate, receiptCh chan TxReceipt[T]) {
	group, ctx := q.groupContext()
	group.Go(func() error {
		return q.sendTx(ctx, id, candidate, receiptCh)
	})
}

func (q *Queue[T]) SendStep2Routine() {
	wg := sync.WaitGroup{}
	lock := sync.Mutex{}
	candidates := []TxCandidate{}
	go func() {
		for {
			select {
			case c := <-q.daConfirmedReceiptQueue:
				fmt.Println("============ add candidate to l1 queue ============")
				lock.Lock()
				candidates = append(candidates, c)
				lock.Unlock()
			}
		}
	}()

	ticker := time.NewTicker(time.Minute)
	for {
		if len(candidates) < 3 {
			time.Sleep(time.Minute)
			continue
		}
		select {
		case <-ticker.C:
			lock.Lock()
			for _, l1Candidate := range candidates {
				wg.Add(1)
				go func(candidate TxCandidate) {
					fmt.Println("== prepare send tx to l1")
					receipt, err := q.txMgr.Send(context.Background(), candidate)
					if err != nil {
						panic(fmt.Errorf("send tx to l1 failed: %w", err))
					}
					fmt.Println("== send tx to l1 success", receipt.BlockNumber)
					wg.Done()
					q.sem.Release(1)
				}(l1Candidate)
				time.Sleep(time.Millisecond * 100)
			}
			candidates = []TxCandidate{}
			lock.Unlock()
			wg.Wait()
		}
	}

}

func (q *Queue[T]) StoreOnDaServer(daServer string, id T, candidate TxCandidate, receiptCh chan TxReceipt[T]) {
	// clone candidate
	l1Candidate := candidate
	if !q.sem.TryAcquire(1) {
		time.Sleep(time.Minute)
		receiptCh <- TxReceipt[T]{
			ID:      id,
			Receipt: nil,
			Err:     fmt.Errorf("too many pending txs"),
		}
		return
	}
	group, _ := q.groupContext()
	group.Go(func() error {
		blobKey, err := StoreBlob(daServer+"/store", candidate.TxData)
		if err != nil {
			time.Sleep(time.Minute)
			receiptCh <- TxReceipt[T]{
				ID:      id,
				Receipt: nil,
				Err:     fmt.Errorf("Store blob on daServer failed: %w", err),
			}
			return err
		}
		fmt.Println("blobkey", blobKey)
		height := strings.Split(blobKey, "/")
		blockHeight, _ := new(big.Int).SetString(height[2], 10)

		receiptCh <- TxReceipt[T]{
			ID: id,
			Receipt: &types.Receipt{
				BlockNumber: blockHeight,
			},
			Err: err,
		}

		l1Candidate.TxData = append([]byte{2}, blobKey...)
		q.daConfirmedReceiptQueue <- l1Candidate

		return err
	})
}

func (q *Queue[T]) Send2Step(id T, candidate TxCandidate, receiptCh chan TxReceipt[T]) {
	// clone candidate
	l1Candidate := candidate
	if !q.sem.TryAcquire(1) {
		time.Sleep(time.Minute)
		receiptCh <- TxReceipt[T]{
			ID:      id,
			Receipt: nil,
			Err:     fmt.Errorf("too many pending txs"),
		}
		return
	}
	group, ctx := q.groupContext()
	group.Go(func() error {
		receipt, err := q.daTxMgr.Send(ctx, candidate) //after short period of time
		receiptCh <- TxReceipt[T]{
			ID:      id,
			Receipt: receipt,
			Err:     err,
		}
		if err != nil {
			return err
		}

		go func() {
			for {
				latestBlock, _ := q.daTxMgr.(*SimpleTxManager).backend.BlockNumber(context.Background())
				if receipt.BlockNumber.Uint64() < latestBlock-375 {
					break
				}
				time.Sleep(time.Second * 1)
			}
			header, _ := q.daTxMgr.(*SimpleTxManager).backend.HeaderByNumber(context.Background(), receipt.BlockNumber)
			if header.Hash().String() != receipt.BlockHash.String() {
				panic("DA tx is forked! We need to reboot")
			}

			l1Candidate.TxData = append([]byte{1}, receipt.TxHash.Bytes()...)
			q.daConfirmedReceiptQueue <- l1Candidate
		}()

		return err
	})
}

// TrySend sends the next tx, but only if the number of pending txs is below the
// max pending.
//
// Returns false if there is no room in the queue to send. Otherwise, the
// transaction is queued and this method returns true.
//
// The actual tx sending is non-blocking, with the receipt returned on the
// provided receipt channel. If the channel is unbuffered, the goroutine is
// blocked from completing until the channel is read from.
func (q *Queue[T]) TrySend(id T, candidate TxCandidate, receiptCh chan TxReceipt[T]) bool {
	group, ctx := q.groupContext()
	return group.TryGo(func() error {
		return q.sendTx(ctx, id, candidate, receiptCh)
	})
}

func (q *Queue[T]) sendTx(ctx context.Context, id T, candidate TxCandidate, receiptCh chan TxReceipt[T]) error {
	receipt, err := q.txMgr.Send(ctx, candidate)
	receiptCh <- TxReceipt[T]{
		ID:      id,
		Receipt: receipt,
		Err:     err,
	}
	return err
}

// groupContext returns a Group and a Context to use when sending a tx.
//
// If any of the pending transactions returned an error, the queue's shared error Group is
// canceled. This method will wait on that Group for all pending transactions to return,
// and create a new Group with the queue's global context as its parent.
func (q *Queue[T]) groupContext() (*errgroup.Group, context.Context) {
	q.groupLock.Lock()
	defer q.groupLock.Unlock()
	if q.groupCtx == nil || q.groupCtx.Err() != nil {
		// no group exists, or the existing context has an error, so we need to wait
		// for existing group threads to complete (if any) and create a new group
		if q.group != nil {
			_ = q.group.Wait()
		}
		q.group, q.groupCtx = errgroup.WithContext(q.ctx)
		if q.maxPending > 0 {
			q.group.SetLimit(int(q.maxPending))
		}
	}
	return q.group, q.groupCtx
}
