## BVM Optimistic rollups
Bitcoin, scaled. NOS is a fast, stable, and scalable Bitcoin L2 blockchain.

## Introduction
By bringing smart contracts to Bitcoin, Bitcoin Virtual Machine lets developers create DEX, DAO, tokens, data storage, and many other use cases on Bitcoin. However, the biggest challenge is Bitcoin's 10-min block time.

Increasing Bitcoin capability in terms of speed is fundamental to the mass adoption of decentralized applications on Bitcoin. 

The main goal of NOS (or "Nitrous Oxide") is to turbocharge Bitcoin transactions (reduce transaction latency) without sacrificing decentralization or security.

## Architecture

NOS reuses the battle-tested [Optimism](https://www.optimism.io/) codebase. It is a modified version of the OP Stack that adds support for Bitcoin.

Like Optimism, NOS uses [Optimistic Rollup](https://ethereum.org/en/developers/docs/scaling/optimistic-rollups/), a fancy way of describing a blockchain that piggybacks off the security of another blockchain. 

In this case, NOS takes advantage of the consensus mechanism of Bitcoin instead of its own. This is possible thanks to the Bitcoin Virtual Machine protocol, which brings smart contract capability to Bitcoin.


![image](https://github.com/user-attachments/assets/8163d702-8037-432f-a297-b02fddd53390)


## LAYER 1

### Data Validation

Implementation: [The Bitcoin Network](https://bitcoin.org/)

The foundation of the NOS software stack is the Data Validation component. This component significantly impacts the security model of the whole stack. Everything else in the entire stack is derived from the Data Validation component.

### Data Availability: 

Implementation: [The Polygon Network](https://polygon.technology/)

For pragmatic reasons, NOS currently stores data on both Bitcoin and Polygon. Bitcoin is arguably the most secure blockchain. NOS stores the data hash on Bitcoin. Polygon is the most cost-effective storage solution. NOS stores the data (compressed transactions) on Polygon.

### Smart Contract Platform

Implementation: [Bitcoin Virtual Machine #0](https://docs.bvm.network/bvm/bitcoin-chains/shards-wip/case-study-op_evm-shard)

Bitcoin Virtual Machine #0 is a special computer. It is a modified version of the EVM that adds smart contracts to Bitcoin. Bitcoin Virtual Machine #0 is used to glue all the components of the NOS software stack together.


## LAYER 2
### Sequencer

Implementation: [op-batcher](https://github.com/TrustlessComputer/optimism-tc/tree/master/op-batcher)

A sequencer (block producer) determines how transactions are collected and published to Layer 1. The sequencer compresses transactions into batches and writes these batches to Polygon, and writes the hash to Bitcoin via Bitcoin Virtual Machine to ensure data availability and integrity.

NOS blocks are currently produced every 2 seconds.

![image](https://github.com/user-attachments/assets/29945761-9392-4ccb-9aea-1a6f482b8b47)

### Rollup Node

Implementation: [op-node](https://github.com/TrustlessComputer/optimism-tc/tree/master/op-node)

The Rollup node defines how the raw data stored in the Data Availability component (Polygon) is processed to form the inputs for the Execution Engine.
This is also referred to as the Derivation component, which derives the L2 blocks from the L1 blocks.

### Execution Engine

Implementation: [op-geth](https://github.com/TrustlessComputer/opgeth-tc)

The Execution Engine defines the state transition function. It takes inputs from the Rollup node, executes on the current state, and outputs the new state.
op-geth is a modified version of the EVM that adds support for L2 transactions.

### Settlement

Implementation: [op-proposer](https://github.com/TrustlessComputer/optimism-tc/tree/master/op-proposer)

The Settlement component commits the Merkle root of the new state (the output from the Execution Engine) to Bitcoin.
Note that the state roots are not immediately valid. In an optimistic rollup setup, state commitments are published onto Bitcoin as pending validity for a period (currently, set as 7 days) and subject to challenge.
The Optimism team is developing the fault-proof process. Once it’s completed, we’ll add it to NOS.

![image](https://github.com/user-attachments/assets/e2395749-82fa-43e2-bab2-5d0e8322eaa7)

## GOVERNANCE LAYER

### Token

Implementation: NOS as a BRC-20 token

NOS is the governance token to decentralize decision-making.

### DAO

Implementation: Under development

The NOS DAO manages NOS configurations, upgrades, design decisions, development grants, etc.

## Directory Structure

<pre>
~~ Production ~~
├── <a href="./packages">packages</a>
│   ├── <a href="./packages/common-ts">common-ts</a>: Common tools for building apps in TypeScript
│   ├── <a href="./packages/contracts">contracts</a>: L1 and L2 smart contracts for Optimism
│   ├── <a href="./packages/contracts-periphery">contracts-periphery</a>: Peripheral contracts for Optimism
│   ├── <a href="./packages/core-utils">core-utils</a>: Low-level utilities that make building Optimism easier
│   ├── <a href="./packages/data-transport-layer">data-transport-layer</a>: Service for indexing Optimism-related L1 data
│   ├── <a href="./packages/chain-mon">chain-mon</a>: Chain monitoring services
│   ├── <a href="./packages/fault-detector">fault-detector</a>: Service for detecting Sequencer faults
│   ├── <a href="./packages/message-relayer">message-relayer</a>: Tool for automatically relaying L1<>L2 messages in development
│   ├── <a href="./packages/replica-healthcheck">replica-healthcheck</a>: Service for monitoring the health of a replica node
│   └── <a href="./packages/sdk">sdk</a>: provides a set of tools for interacting with Optimism
├── <a href="./batch-submitter">batch-submitter</a>: Service for submitting batches of transactions and results to L1
├── <a href="./bss-core">bss-core</a>: Core batch-submitter logic and utilities
├── <a href="./gas-oracle">gas-oracle</a>: Service for updating L1 gas prices on L2
├── <a href="./indexer">indexer</a>: indexes and syncs transactions
├── <a href="./infra/op-replica">infra/op-replica</a>: Deployment examples and resources for running an Optimism replica
├── <a href="./integration-tests">integration-tests</a>: Various integration tests for the Optimism network
├── <a href="./l2geth">l2geth</a>: Optimism client software, a fork of <a href="https://github.com/ethereum/go-ethereum/tree/v1.9.10">geth v1.9.10</a>
├── <a href="./l2geth-exporter">l2geth-exporter</a>: A prometheus exporter to collect/serve metrics from an L2 geth node
├── <a href="./op-exporter">op-exporter</a>: A prometheus exporter to collect/serve metrics from an Optimism node
├── <a href="./proxyd">proxyd</a>: Configurable RPC request router and proxy
├── <a href="./technical-documents">technical-documents</a>: audits and post-mortem documents

~~ BEDROCK upgrade - Not production-ready yet, part of next major upgrade ~~
├── <a href="./packages">packages</a>
│   └── <a href="./packages/contracts-bedrock">contracts-bedrock</a>: Bedrock smart contracts. To be merged with ./packages/contracts.
├── <a href="./op-bindings">op-bindings</a>: Go bindings for Bedrock smart contracts.
├── <a href="./op-batcher">op-batcher</a>: L2-Batch Submitter, submits bundles of batches to L1
├── <a href="./op-e2e">op-e2e</a>: End-to-End testing of all bedrock components in Go
├── <a href="./op-node">op-node</a>: rollup consensus-layer client.
├── <a href="./op-proposer">op-proposer</a>: L2-Output Submitter, submits proposals to L1
├── <a href="./ops-bedrock">ops-bedrock</a>: Bedrock devnet work
└── <a href="./specs">specs</a>: Specs of the rollup starting at the Bedrock upgrade
</pre>


## License

Code forked from [`go-ethereum`](https://github.com/ethereum/go-ethereum) under the name [`l2geth`](https://github.com/ethereum-optimism/optimism/tree/master/l2geth) is licensed under the [GNU GPLv3](https://gist.github.com/kn9ts/cbe95340d29fc1aaeaa5dd5c059d2e60) in accordance with the [original license](https://github.com/ethereum/go-ethereum/blob/master/COPYING).

All other files within this repository are licensed under the [MIT License](https://github.com/ethereum-optimism/optimism/blob/master/LICENSE) unless stated otherwise.
