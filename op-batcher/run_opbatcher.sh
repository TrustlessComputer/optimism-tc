#!/bin/bash
cd /app

echo "TCHOST" $TCHOST
echo "GETH_HOST" $GETH_HOST
echo "OPNODE_HOST" $OPNODE_HOST
echo "DA_RPC" $DA_RPC
echo "DA_SERVER" $DA_SERVER

DACONFIRM=20

if [ "$DA_TYPE" == "" ]; then
    DA_TYPE="POLYGON"
fi

if [ "$DA_TYPE" == "BTC" ]; then
    DACONFIRM=1
fi

./bin/op-batcher \
      --l2-eth-rpc=$GETH_HOST \
      --rollup-rpc=$OPNODE_HOST \
      --poll-interval=1s \
      --sub-safety-margin=6 \
      --num-confirmations=1 \
      --safe-abort-nonce-too-low-count=3 \
      --resubmission-timeout=3600s \
      --network-timeout=5s \
      --rpc.addr=0.0.0.0 \
      --rpc.port=8548 \
      --rpc.enable-admin \
      --max-channel-duration=1 \
      --l1-eth-rpc=$TCHOST \
      --log.level=debug \
      --l1-da-rpc=$DA_RPC \
      --l1-da-type=$DA_TYPE \
      --num-confirmations-da=$DACONFIRM \
      --private-key=$BatcherPriv 2>&1 | cronolog $PWD/resources/logs/%Y-%m-%d.log
