#!/bin/bash
cd /app

echo "TCHOST" $TCHOST

if [ "$DA_TYPE" == "BTC" ]; then
    DA_RPC=$TCHOST
fi

if [ "$DA_TYPE" == "POLYGON" ]; then
    DA_RPC=$POLYGON
fi

#BTC | POLYGON | CELESTIA | EIGEN
echo "DA_TYPE" $DA_TYPE
echo "POLYGON" $POLYGON
echo "CELESTIA" $CELESTIA
echo "EIGEN" $EIGEN

#legacy config
echo "DA_RPC" $DA_RPC

if [ "$P2PPORT" == "" ]; then
    P2PPORT=9003
fi

P2PSTATIC_CFG=""
if [ "$P2PSTATIC" != "" ]; then
    P2PSTATIC_CFG="--p2p.static=$P2PSTATIC"
fi

if [ "$MASTER" == "1" ]; then
  ./bin/op-node \
    --l2=$GETH_HOST \
    --l2.jwt-secret=./resources/jwt.txt \
    --sequencer.enabled \
    --sequencer.l1-confs=6 \
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
    --l1-da-rpc=$DA_RPC \
    --log.level info 2>&1 | cronolog $PWD/resources/logs/%Y-%m-%d.log
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
    --p2p.no-discovery $P2PSTATIC_CFG\
    --rpc.enable-admin \
    --l1=$TCHOST \
    --l1.trustrpc=true \
    --l1.rpckind=basic \
    --l1.epoch-poll-interval=10s \
    --l1-da-rpc=$DA_RPC \
    --log.level info 2>&1 | cronolog $PWD/resources/logs/%Y-%m-%d.log
fi



