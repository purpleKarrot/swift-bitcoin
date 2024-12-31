import Foundation
import AsyncAlgorithms
import BitcoinCrypto
import BitcoinBase

public actor BlockchainService: Sendable {

    public enum Error: Swift.Error {
        case unsupportedBlockVersion, orphanHeader, insuficientProofOfWork, headerTooOld, headerTooNew
    }

    let consensusParams: ConsensusParams
    public private(set) var blocks = [TxBlock]()
    public private(set) var mempool = [BitcoinTx]()
    public private(set) var tip = 0

    /// Subscriptions to new blocks.
    private var blockChannels = [AsyncChannel<TxBlock>]()

    public init(consensusParams: ConsensusParams = .regtest) {
        self.consensusParams = consensusParams
        let genesisBlock = TxBlock.makeGenesisBlock(consensusParams: consensusParams)
        blocks.append(genesisBlock)
        tip += 1
    }

    public var genesisBlock: TxBlock {
        blocks[0]
    }

    public func getBlock(_ height: Int) -> TxBlock {
        precondition(height < tip)
        return blocks[height]
    }

    public func getBlock(_ id: BlockID) -> TxBlock? {
        guard let index = blocks.firstIndex(where: { $0.id == id }), index < tip else {
            return .none
        }
        return blocks[index]
    }

    /// Adds a transaction to the mempool.
    public func addTx(_ tx: BitcoinTx) throws {
        // TODO: Check transaction.
        guard getTx(tx.id) == .none else { return }
        mempool.append(tx)
    }

    public func createGenesisBlock() {
        guard blocks.isEmpty else { return }
        let genesisBlock = TxBlock.makeGenesisBlock(consensusParams: consensusParams)
        blocks.append(genesisBlock)
        tip += 1
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
        precondition(!blocks.isEmpty)

        var have = [Data]()
        var index = blocks.endIndex - 1
        var step = 1
        while index >= 0 {
            let header = blocks[index]
            have.append(header.id)
            if index == 0 { break }

            // Exponentially larger steps back, plus the genesis block.
            if have.count >= 10 { step *= 2 }
            index = max(index - step, 0) // TODO: Use "skiplist"
        }
        return have
    }

    public func findHeaders(using locator: [Data]) -> [TxBlock] {
        var from = Int?.none
        for id in locator {
            for index in blocks.indices {
                let header = blocks[index]
                if header.id == id {
                    from = index
                    break
                }
            }
            if from != .none { break }
        }
        guard let from else { return [] }
        let firstIndex = from.advanced(by: 1)
        var lastIndex = tip
        if firstIndex >= lastIndex { return [] }
        if lastIndex - firstIndex > 200 {
            lastIndex = from.advanced(by: 200)
        }
        var headers = [TxBlock]()
        for var block in blocks[firstIndex ..< lastIndex] {
            block.txs = []
            headers.append(block)
        }
        return headers
    }

    public func processHeaders(_ newHeaders: [TxBlock]) throws {
        var height = blocks.count
        for var newHeader in newHeaders {

            guard newHeader.version == 0x20000000 else {
                throw Error.unsupportedBlockVersion
            }

            let lastVerifiedHeader = blocks.last!
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

            let target = getNextWorkRequired(forHeight: blocks.endIndex.advanced(by: -1), newBlockTime: newHeader.time, params: consensusParams)
            guard DifficultyTarget(compact: newHeader.target) <= DifficultyTarget(compact: target), DifficultyTarget(newHeader.hash) <= DifficultyTarget(compact: newHeader.target) else {
                throw Error.insuficientProofOfWork
            }
            let chainwork = lastVerifiedHeader.work + newHeader.work
            newHeader.context = .init(height: height, chainwork: chainwork, status: .header)
            blocks.append(newHeader)
            height += 1
        }
    }

    public func getNextMissingBlocks(_ numberOfBlocks: Int) -> [Data] {
        let delta = blocks.count - tip
        let realNumberOfBlocks = min(numberOfBlocks, delta)
        var hashes = [Data]()
        for i in tip ..< (tip + realNumberOfBlocks) {
            hashes.append(blocks[i].id)
        }
        return hashes
    }

    public func getBlocks(_ hashes: [Data]) -> [TxBlock] {
        var ret = [TxBlock]()
        for hash in hashes {
            guard let index = blocks.firstIndex(where: { $0.id == hash }),
                  index < tip else {
                continue
            }
            ret.append(blocks[index])
        }
        return ret
    }

    public func processBlock(_ block: TxBlock) {
        if tip < blocks.count {
            guard block.headerData == blocks[tip].headerData else {
                return
            }
        } else if block.previous == blocks[tip - 1].id {
            return
        }
        // Verify merkle root
        let expectedMerkleRoot = calculateMerkleRoot(block.txs)
        guard block.merkleRoot == expectedMerkleRoot else {
            return
        }
        // TODO: Verify each transaction
        for t in block.txs {
            do {
                try t.check()
                // TODO: `try t.checkIns(coins: [], spendHeight: [])`
                // TODO: `try t.isFinal(blockHeight: T##Int?, blockTime: T##Int?)`
                // TODO: `t.checkSequenceLocks(verifyLockTimeSequence: T##Bool, coins: T##[TxOutpoint : UnspentOut], chainTip: T##Int, previousBlockMedianTimePast: T##Int)
                // TODO: Task { t.verifyScript(prevouts: T##[TxOut], config: T##ScriptConfig) }
            } catch {
                return
            }
        }
        let chainwork = blocks[tip - 1].work + block.work
        var newBlock = block
        newBlock.context =  .init(height: tip, chainwork: chainwork, status: .full)
        if tip < blocks.count {
            blocks[tip] = newBlock
        } else {
            blocks.append(newBlock)
        }
        tip += 1
        // TODO: Notify other nodes of new tip
    }

    public func generateTo(_ publicKey: PublicKey, blockTime: Date = .now) {
        generateTo(Data(Hash160.hash(data: publicKey.data)), blockTime: blockTime)
    }

    public func generateTo(_ publicKeyHash: Data, blockTime: Date = .now) {
        if blocks.isEmpty {
            createGenesisBlock()
        }

        guard tip == blocks.count else {
            // Waiting for pending block transactions for known headers
            return
        }

        let witnessMerkleRoot = calculateWitnessMerkleRoot(mempool)
        let coinbaseTx = BitcoinTx.makeCoinbaseTx(blockHeight: tip, publicKeyHash: publicKeyHash, witnessMerkleRoot: witnessMerkleRoot, blockSubsidy: consensusParams.blockSubsidy)

        let previousBlockHash = blocks.last!.id
        let newTxs = [coinbaseTx] + mempool
        let merkleRoot = calculateMerkleRoot(newTxs)

        let target = getNextWorkRequired(forHeight: tip - 1, newBlockTime: blockTime, params: consensusParams)

        var nonce = 0
        var header: TxBlock
        repeat {
            header = .init(
                version: 0x20000000,
                previous: previousBlockHash,
                merkleRoot: merkleRoot,
                time: blockTime,
                target: target,
                nonce: nonce
            )
            nonce += 1
        } while DifficultyTarget(header.hash) > DifficultyTarget(compact: target)

        let chainwork = blocks.last!.work + DifficultyTarget.getWork(target)
        let blockFound = TxBlock(
            context: .init(height: tip, chainwork: chainwork, status: .full),
            version: header.version, previous: header.previous, merkleRoot: header.merkleRoot, time: header.time, target: header.target, nonce: header.nonce,
            txs: newTxs
        )
        blocks.append(blockFound)
        tip += 1
        mempool = .init()
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
        for block in blocks {
            for t in block.txs {
                if t.id == id {
                    return t
                }
            }
        }
        return .none
    }

    private func getNextWorkRequired(forHeight heightLast: Int, newBlockTime: Date, params: ConsensusParams) -> Int {
        precondition(heightLast >= 0)
        let lastHeader = blocks[heightLast]
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
                        header = blocks[height]
                    }
                    return header.target
                }
            }
            return lastHeader.target
        }

        // Go back by what we want to be 14 days worth of blocks
        let heightFirst = heightLast - (params.difficultyAdjustmentInterval - 1)
        precondition(heightFirst >= 0)
        let firstHeader = blocks[heightFirst] // pindexLast->GetAncestor(nHeightFirst)
        return calculateNextWorkRequired(lastHeader: lastHeader, firstBlockTime: firstHeader.time, params: params)
    }

    private func calculateNextWorkRequired(lastHeader: TxBlock, firstBlockTime: Date, params: ConsensusParams) -> Int {
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
        let height = height ?? blocks.count - 1
        precondition(height >= 0 && height < blocks.count)
        let start = max(height - 11, 0)
        let median = blocks.lazy.map(\.time)[start...height].sorted()
        precondition(median.startIndex == 0)
        return median[median.count / 2]
    }
}
