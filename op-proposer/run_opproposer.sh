#!/bin/bash
cd /app

echo "TCHOST" $TCHOST
echo "L2OO_ADDR" $L2OO_ADDR
echo "OPNODE_HOST" $OPNODE_HOST

./bin/op-proposer \
  --poll-interval 12s \
  --rpc.port 8560 \
  --resubmission-timeout=600s \
  --num-confirmations=1 \
  --rollup-rpc $OPNODE_HOST \
  --l2oo-address $L2OO_ADDR \
  --private-key $ProposerPriv \
  --log.level  debug \
  --l1-eth-rpc $TCHOST 2>&1 | cronolog $PWD/resources/logs/%Y-%m-%d.log
