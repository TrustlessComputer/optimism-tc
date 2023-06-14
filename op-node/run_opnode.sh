#!/bin/bash
cd /app

echo "TCHOST" $TCHOST


./bin/op-node \
      --l2=$GETH_HOST \
      --l2.jwt-secret=./resources/jwt.txt \
      --sequencer.enabled \
      --sequencer.l1-confs=6 \
      --verifier.l1-confs=1 \
      --rollup.config=./resources/rollup.json \
      --rpc.addr=0.0.0.0 \
      --rpc.port=8547 \
      --p2p.disable \
      --rpc.enable-admin \
      --p2p.sequencer.key=$SequencerPriv \
      --l1=$TCHOST \
      --l1.trustrpc=true \
      --l1.rpckind=basic \
      --l1.epoch-poll-interval=10s \
      --log.level trace 2>&1 | cronolog $PWD/resources/logs/%Y-%m-%d.log
