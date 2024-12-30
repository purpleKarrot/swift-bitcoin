import Foundation
import AsyncAlgorithms
import BitcoinCrypto
import BitcoinBase

public actor BlockchainService: Sendable {

    public enum Error: Swift.Error {
        case unsupportedBlockVersion, orphanHeader, insuficientProofOfWork, headerTooOld, headerTooNew
    }

    let consensusParams: ConsensusParams
    public private(set) var headers = [BlockHeader]()
    public private(set) var txs = [[BitcoinTx]]()
    public private(set) var mempool = [BitcoinTx]()

    /// Subscriptions to new blocks.
    private var blockChannels = [AsyncChannel<TxBlock>]()

    public init(consensusParams: ConsensusParams = .regtest) {
        self.consensusParams = consensusParams
        let genesisBlock = TxBlock.makeGenesisBlock(consensusParams: consensusParams)
        headers.append(genesisBlock.header)
        txs.append(genesisBlock.txs)
    }

    public var genesisBlock: TxBlock {
        .init(header: headers[0], txs: txs[0])
    }

    public func getBlock(_ height: Int) -> TxBlock {
        precondition(height < txs.count)
        return .init(header: headers[height], txs: txs[height])
    }

    public func getBlock(_ id: BlockID) -> TxBlock? {
        guard let index = headers.firstIndex(where: { $0.id == id }), index < txs.endIndex else {
            return .none
        }
        let header = headers[index]
        let txs = txs[index]
        return .init(header: header, txs: txs)
    }

    /// Adds a transaction to the mempool.
    public func addTx(_ tx: BitcoinTx) throws {
        // TODO: Check transaction.
        guard getTx(tx.id) == .none else { return }
        mempool.append(tx)
    }

    public func createGenesisBlock() {
        guard txs.isEmpty else { return }
        let genesisBlock = TxBlock.makeGenesisBlock(consensusParams: consensusParams)
        headers.append(genesisBlock.header)
        txs.append(genesisBlock.txs)
    }

    public func subscribeToBlocks() -> AsyncChannel<TxBlock> {
        blockChannels.append(.init())
        return blockChannels.last!
    }

    public func shutdown() {
        for channel in blockChannels {
            channel.finish()
        }
    }

    public func unsubscribe(_ channel: AsyncChannel<TxBlock>) {
        channel.finish()
        blockChannels.removeAll(where: { $0 === channel })
    }

    /// To create the block locator hashes, keep pushing hashes until you go back to the genesis block. After pushing 10 hashes back, the step backwards doubles every loop.
    public func makeBlockLocator() -> [Data] {
        precondition(!headers.isEmpty)

        var have = [Data]()
        var index = headers.endIndex - 1
        var step = 1
        while index >= 0 {
            let header = headers[index]
            have.append(header.id)
            if index == 0 { break }

            // Exponentially larger steps back, plus the genesis block.
            if have.count >= 10 { step *= 2 }
            index = max(index - step, 0) // TODO: Use "skiplist"
        }
        return have
    }

    public func findHeaders(using locator: [Data]) -> [BlockHeader] {
        var from = Int?.none
        for id in locator {
            for index in headers.indices {
                let header = headers[index]
                if header.id == id {
                    from = index
                    break
                }
            }
            if from != .none { break }
        }
        guard let from else { return [] }
        let firstIndex = from.advanced(by: 1)
        var lastIndex = txs.endIndex
        if firstIndex >= lastIndex { return [] }
        if lastIndex - firstIndex > 200 {
            lastIndex = from.advanced(by: 200)
        }
        return .init(headers[firstIndex ..< lastIndex])
    }

    public func processHeaders(_ newHeaders: [BlockHeader]) throws {
        for newHeader in newHeaders {

            guard newHeader.version == 0x20000000 else {
                throw Error.unsupportedBlockVersion
            }

            let lastVerifiedHeader = headers.last!
            guard lastVerifiedHeader.id == newHeader.previous else {
                throw Error.orphanHeader
            }

            guard newHeader.time >= getMedianTimePast() else {
                throw Error.headerTooOld
            }

            var calendar = Calendar(identifier: .iso8601)
            calendar.timeZone = .gmt
            guard newHeader.time <= calendar.date(byAdding: .hour, value: 2, to: .now)! else {
                throw Error.headerTooNew
            }

            let target = getNextWorkRequired(forHeight: txs.endIndex.advanced(by: -1), newBlockTime: newHeader.time, params: consensusParams)
            guard DifficultyTarget(compact: newHeader.target) <= DifficultyTarget(compact: target), DifficultyTarget(newHeader.hash) <= DifficultyTarget(compact: newHeader.target) else {
                throw Error.insuficientProofOfWork
            }
            headers.append(newHeader)
        }
    }

    public func getNextMissingBlocks(_ numberOfBlocks: Int) -> [Data] {
        let lastBlockIndex = txs.count
        let delta = headers.count - txs.count
        let realNumberOfBlocks = min(numberOfBlocks, delta)
        var hashes = [Data]()
        for i in lastBlockIndex ..< (lastBlockIndex + realNumberOfBlocks) {
            hashes.append(headers[i].id)
        }
        return hashes
    }

    public func getBlocks(_ hashes: [Data]) -> [(BlockHeader, [BitcoinTx])] {
        var ret = [(BlockHeader, [BitcoinTx])]()
        for hash in hashes {
            guard let index = headers.firstIndex(where: { $0.id == hash }),
                  index < txs.count else {
                continue
            }
            ret.append((
                headers[index],
                txs[index]
            ))
        }
        return ret
    }

    public func processBlock(header: BlockHeader, txs blockTxs: [BitcoinTx]) {
        if headers.count > txs.count {
            guard header == headers[txs.count] else { return }
        } else {
            guard header.previous == headers[headers.count - 1].id else {
                return
            }
            headers.append(header)
        }
        // Verify merkle root
        let expectedMerkleRoot = calculateMerkleRoot(blockTxs)
        guard header.merkleRoot == expectedMerkleRoot else {
            // TODO: remove block header
            return
        }
        // TODO: Verify each transaction
        for t in blockTxs {
            do {
                try t.check()
                // TODO: `try t.checkIns(coins: [], spendHeight: [])`
                // TODO: `try t.isFinal(blockHeight: T##Int?, blockTime: T##Int?)`
                // TODO: `t.checkSequenceLocks(verifyLockTimeSequence: T##Bool, coins: T##[TxOutpoint : UnspentOut], chainTip: T##Int, previousBlockMedianTimePast: T##Int)
                // TODO: Task { t.verifyScript(prevouts: T##[TxOut], config: T##ScriptConfig) }
            } catch {
                // TODO: remove block header
                return
            }
        }
        txs.append(blockTxs)
    }

    public func generateTo(_ publicKey: PublicKey, blockTime: Date = .now) {
        generateTo(Data(Hash160.hash(data: publicKey.data)), blockTime: blockTime)
    }

    public func generateTo(_ publicKeyHash: Data, blockTime: Date = .now) {
        if txs.isEmpty {
            createGenesisBlock()
        }

        let witnessMerkleRoot = calculateWitnessMerkleRoot(mempool)
        let coinbaseTx = BitcoinTx.makeCoinbaseTx(blockHeight: txs.count, publicKeyHash: publicKeyHash, witnessMerkleRoot: witnessMerkleRoot, blockSubsidy: consensusParams.blockSubsidy)

        let previousBlockHash = headers.last!.id
        let newTxs = [coinbaseTx] + mempool
        let merkleRoot = calculateMerkleRoot(newTxs)

        let target = getNextWorkRequired(forHeight: txs.endIndex.advanced(by: -1), newBlockTime: blockTime, params: consensusParams)

        var nonce = 0
        var header: BlockHeader
        repeat {
            header = BlockHeader(
                version: 0x20000000,
                previous: previousBlockHash,
                merkleRoot: merkleRoot,
                time: blockTime,
                target: target,
                nonce: nonce
            )
            nonce += 1
        } while DifficultyTarget(header.hash) > DifficultyTarget(compact: target)

        headers.append(header)
        txs.append(newTxs)
        mempool = .init()

        let blockFound = TxBlock(header: header, txs: newTxs)
        Task {
            await withDiscardingTaskGroup {
                for channel in blockChannels {
                    $0.addTask {
                        await channel.send(blockFound)
                    }
                }
            }
        }
    }

    public func getTx(_ id: TxID) -> BitcoinTx? {
        for t in mempool {
            if t.id == id {
                return t
            }
        }
        for block in txs {
            for t in block {
                if t.id == id {
                    return t
                }
            }
        }
        return .none
    }

    private func getNextWorkRequired(forHeight heightLast: Int, newBlockTime: Date, params: ConsensusParams) -> Int {
        precondition(heightLast >= 0)
        let lastHeader = headers[heightLast]
        let powLimitTarget = DifficultyTarget(Data(params.powLimit.reversed()))
        let proofOfWorkLimit = powLimitTarget.toCompact()

        // Only change once per difficulty adjustment interval
        if (heightLast + 1) % params.difficultyAdjustmentInterval != 0 {
            if params.powAllowMinDifficultyBlocks {
                // Special difficulty rule for testnet:
                // If the new block's timestamp is more than 2* 10 minutes
                // then allow mining of a min-difficulty block.
                if Int(newBlockTime.timeIntervalSince1970) > Int(lastHeader.time.timeIntervalSince1970) + params.powTargetSpacing * 2 {
                    return proofOfWorkLimit
                } else {
                    // Return the last non-special-min-difficulty-rules-block
                    var height = heightLast
                    var header = lastHeader
                    while height > 0 && height % params.difficultyAdjustmentInterval != 0 && header.target == proofOfWorkLimit {
                        height -= 1
                        header = headers[height]
                    }
                    return header.target
                }
            }
            return lastHeader.target
        }

        // Go back by what we want to be 14 days worth of blocks
        let heightFirst = heightLast - (params.difficultyAdjustmentInterval - 1)
        precondition(heightFirst >= 0)
        let firstHeader = headers[heightFirst] // pindexLast->GetAncestor(nHeightFirst)
        return calculateNextWorkRequired(lastHeader: lastHeader, firstBlockTime: firstHeader.time, params: params)
    }

    private func calculateNextWorkRequired(lastHeader: BlockHeader, firstBlockTime: Date, params: ConsensusParams) -> Int {
        if params.powNoRetargeting {
            return lastHeader.target
        }

        // Limit adjustment step
        var actualTimespan = Int(lastHeader.time.timeIntervalSince1970) - Int(firstBlockTime.timeIntervalSince1970)
        if actualTimespan < params.powTargetTimespan / 4 {
            actualTimespan = params.powTargetTimespan / 4
        }
        if actualTimespan > params.powTargetTimespan * 4 {
            actualTimespan = params.powTargetTimespan * 4
        }

        // Retarget
        let powLimitTarget = DifficultyTarget(Data(params.powLimit.reversed()))

        var new = DifficultyTarget(compact: lastHeader.target)
        precondition(!new.isZero)
        new *= (UInt32(actualTimespan))
        new /= DifficultyTarget(UInt64(params.powTargetTimespan))

        if new > powLimitTarget { new = powLimitTarget }

        return new.toCompact()
    }

    private func getMedianTimePast(for height: Int? = .none) -> Date {
        let height = height ?? headers.count - 1
        precondition(height >= 0 && height < headers.count)
        let start = max(height - 11, 0)
        let median = headers.lazy.map(\.time)[start...height].sorted()
        precondition(median.startIndex == 0)
        return median[median.count / 2]
    }
}
