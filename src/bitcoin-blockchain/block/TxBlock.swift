import Foundation
import BitcoinCrypto
import BitcoinBase

/// A block of transactions.
public struct TxBlock: Equatable, Sendable {

    // MARK: - Initializers

    public init(header: BlockHeader, txs: [BitcoinTx] = []) {
        self.header = header
        self.txs = txs
    }

    // MARK: - Instance Properties

    public let header: BlockHeader
    public let txs: [BitcoinTx]

    // MARK: - Computed Properties

    // MARK: - Instance Methods

    // MARK: - Type Properties

    // MARK: - Type Methods

    static func makeGenesisBlock(consensusParams: ConsensusParams) -> Self {
        let genesisTx = BitcoinTx.makeGenesisTx(blockSubsidy: consensusParams.blockSubsidy)
        let genesisBlock = TxBlock(
            header: .init(
                version: 1,
                previous: Data(count: 32),
                merkleRoot: genesisTx.id,
                time: Date(timeIntervalSince1970: TimeInterval(consensusParams.genesisBlockTime)),
                target: consensusParams.genesisBlockTarget,
                nonce: consensusParams.genesisBlockNonce
            ),
            txs: [genesisTx])
        return genesisBlock
    }
}

package extension TxBlock {

    /// Initialize from serialized raw data.
    init?(_ data: Data) {
        // Check we at least have enough data for block header + empty transactions
        guard data.count > BlockHeader.size else {
            return nil
        }
        var data = data

        // Header
        guard let header = BlockHeader(data) else {
            return nil
        }
        data = data.dropFirst(BlockHeader.size)
        guard let txCount = data.varInt, txCount <= Int.max else {
            return nil
        }
        data = data.dropFirst(txCount.varIntSize)
        var txs = [BitcoinTx]()
        for _ in 0 ..< txCount {
            guard let tx = BitcoinTx(data) else {
                return nil
            }
            txs.append(tx)
            data = data.dropFirst(tx.size)
        }
        self.header = header
        self.txs = txs
    }

    var data: Data {
        var ret = Data(count: size)
        var offset = ret.addData(header.data)
        offset = ret.addData(Data(varInt: UInt64(txs.count)), at: offset)
        ret.addData(Data(txs.map(\.data).joined()), at: offset)
        return ret
    }

    /// Size of data in bytes.
    var size: Int {
        BlockHeader.size + UInt64(txs.count).varIntSize + txs.reduce(0) { $0 + $1.size }
    }
}

/// BIP152: Short transaction identifier implementation. See [https://github.com/bitcoin/bips/blob/master/bip-0152.mediawiki#short-transaction-ids].
extension TxBlock {

    /// Short transaction IDs are used to represent a transaction without sending a full 256-bit hash. They are calculated by:
    ///   1. single-SHA256 hashing the block header with the nonce appended (in little-endian)
    ///   2. Running SipHash-2-4 with the input being the transaction ID and the keys (k0/k1) set to the first two little-endian 64-bit integers from the above hash, respectively.
    ///   3. Dropping the 2 most significant bytes from the SipHash output to make it 6 bytes.
    public func makeShortTxID(for txIndex: Int, nonce: UInt64) -> Int {

        // single-SHA256 hashing the block header with the nonce appended (in little-endian)
        let headerData = header.data + Data(value: nonce)
        let headerHash = Data(SHA256.hash(data: headerData))

        // Running SipHash-2-4 with the input being the transaction ID and the keys (k0/k1) set to the first two little-endian 64-bit integers from the above hash, respectively.
        let firstInt = headerHash.withUnsafeBytes { $0.load(as: UInt64.self) }
        let secondInt = headerHash.dropFirst(MemoryLayout.size(ofValue: firstInt)).withUnsafeBytes { $0.load(as: UInt64.self) }
        var sipHasher = SipHash(k0: firstInt, k1: secondInt)

        let txID = txs[txIndex].witnessID
        txID.withUnsafeBytes { sipHasher.update(bufferPointer: $0) }
        let sipHash = sipHasher.finalize().value

        // Dropping the 2 most significant bytes from the SipHash output to make it 6 bytes.
        return Int((sipHash << 16) >> 16)
    }
}
