#!/bin/bash
cd /app

echo "TCHOST" $TCHOST


if [ "$P2PPORT" == "" ]; then
    P2PPORT=9003
fi

if [ "$MASTER" == "1" ]; then
  ./bin/op-node \
    --l2=$GETH_HOST \
    --l2.jwt-secret=./resources/jwt.txt \
    --sequencer.enabled \
    --sequencer.l1-confs=1 \
    --verifier.l1-confs=6 \
    --rollup.config=./resources/rollup.json \
    --rpc.addr=0.0.0.0 \
    --rpc.port=8547 \
    --p2p.priv.path=/app/resources/peer.priv \
    --p2p.listen.ip=0.0.0.0 \
    --p2p.listen.tcp=$P2PPORT \
    --p2p.listen.udp=$P2PPORT \
    --p2p.no-discovery \
    --rpc.enable-admin \
    --p2p.sequencer.key=$SequencerPriv \
    --l1=$TCHOST \
    --l1.trustrpc=true \
    --l1.rpckind=basic \
    --l1.epoch-poll-interval=10s \
    --log.level trace 2>&1 | cronolog $PWD/resources/logs/%Y-%m-%d.log
else
  ./bin/op-node \
    --l2=$GETH_HOST \
    --l2.jwt-secret=./resources/jwt.txt \
    --verifier.l1-confs=6 \
    --rollup.config=./resources/rollup.json \
    --rpc.addr=0.0.0.0 \
    --rpc.port=8547 \
    --p2p.priv.path=/app/resources/peer.priv \
    --p2p.listen.ip=0.0.0.0 \
    --p2p.listen.tcp=$P2PPORT \
    --p2p.listen.udp=$P2PPORT \
    --p2p.no-discovery \
    --p2p.static=/ip4/172.17.0.6/tcp/9003/p2p/16Uiu2HAmP2Y4sxECGu2sGedpD7o1bHn8i7XTDes98mtWPeZ5cJxJ \
    --rpc.enable-admin \
    --l1=$TCHOST \
    --l1.trustrpc=true \
    --l1.rpckind=basic \
    --l1.epoch-poll-interval=10s \
    --log.level trace 2>&1 | cronolog $PWD/resources/logs/%Y-%m-%d.log
fi



