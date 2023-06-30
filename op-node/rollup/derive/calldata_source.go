package derive

import (
	"context"
	"errors"
	"fmt"
	"io"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/ethereum-optimism/optimism/op-node/eth"
	"github.com/ethereum-optimism/optimism/op-node/rollup"
)

const (
	HashLength         = 32
	NumConfirmationsDA = 30
)

type DataIter interface {
	Next(ctx context.Context) (eth.Data, error)
}

type L1TransactionFetcher interface {
	InfoAndTxsByHash(ctx context.Context, hash common.Hash) (eth.BlockInfo, types.Transactions, error)
	DADataByTxHash(ctx context.Context, hash common.Hash) (eth.Data, uint64, error)
}

// DataSourceFactory readers raw transactions from a given block & then filters for
// batch submitter transactions.
// This is not a stage in the pipeline, but a wrapper for another stage in the pipeline
type DataSourceFactory struct {
	log     log.Logger
	cfg     *rollup.Config
	fetcher L1TransactionFetcher
}

func NewDataSourceFactory(log log.Logger, cfg *rollup.Config, fetcher L1TransactionFetcher) *DataSourceFactory {
	return &DataSourceFactory{log: log, cfg: cfg, fetcher: fetcher}
}

// OpenData returns a DataIter. This struct implements the `Next` function.
func (ds *DataSourceFactory) OpenData(ctx context.Context, id eth.BlockID, batcherAddr common.Address) DataIter {
	return NewDataSource(ctx, ds.log, ds.cfg, ds.fetcher, id, batcherAddr)
}

// DataSource is a fault tolerant approach to fetching data.
// The constructor will never fail & it will instead re-attempt the fetcher
// at a later point.
type DataSource struct {
	// Internal state + data
	open bool
	data []eth.Data
	// Required to re-attempt fetching
	id      eth.BlockID
	cfg     *rollup.Config // TODO: `DataFromEVMTransactions` should probably not take the full config
	fetcher L1TransactionFetcher
	log     log.Logger

	batcherAddr common.Address
}

// NewDataSource creates a new calldata source. It suppresses errors in fetching the L1 block if they occur.
// If there is an error, it will attempt to fetch the result on the next call to `Next`.
func NewDataSource(ctx context.Context, log log.Logger, cfg *rollup.Config, fetcher L1TransactionFetcher, block eth.BlockID, batcherAddr common.Address) DataIter {
	_, txs, err := fetcher.InfoAndTxsByHash(ctx, block.Hash)
	if err != nil {
		return &DataSource{
			open:        false,
			id:          block,
			cfg:         cfg,
			fetcher:     fetcher,
			log:         log,
			batcherAddr: batcherAddr,
		}
	} else {
		var resultData []eth.Data
		l1data := DataFromEVMTransactions(cfg, batcherAddr, txs, log.New("origin", block))
		for _, data := range l1data {
			txHash := data[1:]
			if len(txHash) != HashLength {
				return &DataSource{
					open:        false,
					id:          block,
					cfg:         cfg,
					fetcher:     fetcher,
					log:         log,
					batcherAddr: batcherAddr,
				}
			}
			if data, numConfirmations, err := fetcher.DADataByTxHash(ctx, common.BytesToHash(txHash)); err == nil {
				if numConfirmations < NumConfirmationsDA {
					return &DataSource{
						open:        false,
						id:          block,
						cfg:         cfg,
						fetcher:     fetcher,
						log:         log,
						batcherAddr: batcherAddr,
					}
				}
				log.Info("retrieved data from calldata source", "data", data, "len", len(data))
				resultData = append(resultData, data)
			} else {
				return &DataSource{
					open:        false,
					id:          block,
					cfg:         cfg,
					fetcher:     fetcher,
					log:         log,
					batcherAddr: batcherAddr,
				}
			}
		}

		return &DataSource{
			open: true,
			data: resultData,
		}
	}
}

// Next returns the next piece of data if it has it. If the constructor failed, this
// will attempt to reinitialize itself. If it cannot find the block it returns a ResetError
// otherwise it returns a temporary error if fetching the block returns an error.
func (ds *DataSource) Next(ctx context.Context) (eth.Data, error) {
	if !ds.open {
		if _, txs, err := ds.fetcher.InfoAndTxsByHash(ctx, ds.id.Hash); err == nil {
			ds.open = true
			var resultData []eth.Data
			l1data := DataFromEVMTransactions(ds.cfg, ds.batcherAddr, txs, log.New("origin", ds.id))
			for _, data := range l1data {
				txHash := data[1:]
				if len(txHash) != HashLength {
					return nil, NewTemporaryError(fmt.Errorf("invalid hash in calldata source %v", txHash))
				}
				if data, numConfirmations, err := ds.fetcher.DADataByTxHash(ctx, common.BytesToHash(txHash)); err == nil {
					if numConfirmations < NumConfirmationsDA {
						return nil, NewTemporaryError(fmt.Errorf("not enough confirmations for data tx %v", txHash))
					}

					log.Info("retrieved data from calldata source", "data", data, "len", len(data))
					resultData = append(resultData, data)
				} else {
					return nil, NewTemporaryError(fmt.Errorf("failed to retrieve data from calldata source: %w", err))
				}
			}
			ds.data = resultData
		} else if errors.Is(err, ethereum.NotFound) {
			return nil, NewResetError(fmt.Errorf("failed to open calldata source: %w", err))
		} else {
			return nil, NewTemporaryError(fmt.Errorf("failed to open calldata source: %w", err))
		}
	}
	if len(ds.data) == 0 {
		return nil, io.EOF
	} else {
		data := ds.data[0]
		ds.data = ds.data[1:]
		return data, nil
	}
}

// DataFromEVMTransactions filters all of the transactions and returns the calldata from transactions
// that are sent to the batch inbox address from the batch sender address.
// This will return an empty array if no valid transactions are found.
func DataFromEVMTransactions(config *rollup.Config, batcherAddr common.Address, txs types.Transactions, log log.Logger) []eth.Data {
	var out []eth.Data
	l1Signer := config.L1Signer()
	for j, tx := range txs {
		if to := tx.To(); to != nil && *to == config.BatchInboxAddress {
			seqDataSubmitter, err := l1Signer.Sender(tx) // optimization: only derive sender if To is correct
			if err != nil {
				log.Warn("tx in inbox with invalid signature", "index", j, "err", err)
				continue // bad signature, ignore
			}
			// some random L1 user might have sent a transaction to our batch inbox, ignore them
			if seqDataSubmitter != batcherAddr {
				log.Warn("tx in inbox with unauthorized submitter", "index", j, "err", err, "seqDataSubmitter", seqDataSubmitter.String(), "batcherAddr", batcherAddr.String())
				continue // not an authorized batch submitter, ignore
			}
			out = append(out, tx.Data())
		}
	}
	return out
}
