import Foundation
import BitcoinCrypto
import BitcoinBase

public typealias BlockID = Data

/// A block's header.
/// A block of transactions.
public struct TxBlock: Equatable, Sendable {

    // MARK: - Initializers

    public init(context: BlockContext? = .none, version: Int = 2, previous: Data, merkleRoot: Data, time: Date = .now, target: Int, nonce: Int = 0, txs: [BitcoinTx] = []) {
        self.context = context
        self.version = version
        self.previous = previous
        self.merkleRoot = merkleRoot

        // Reset date's nanoseconds
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .gmt
        guard let time = calendar.date(bySetting: .nanosecond, value: 0, of: time) else { preconditionFailure() }
        self.time = time

        self.target = target
        self.nonce = nonce
        self.txs = txs
    }

    // MARK: - Instance Properties

    public var context: BlockContext?

    // Header
    public let version: Int
    public let previous: Data
    public let merkleRoot: Data
    public let time: Date

    /// Difficulty bits.
    public let target: Int

    public let nonce: Int

    public var txs: [BitcoinTx]

    // MARK: - Computed Properties

    public var hash: Data {
        Data(Hash256.hash(data: headerData))
    }

    public var id: BlockID {
        Data(hash.reversed())
    }

    public var idHex: String {
        id.hex
    }

    var work: DifficultyTarget { .getWork(target) }

    // MARK: - Instance Methods

    // MARK: - Type Properties

    public static let idLength = Hash256.Digest.byteCount

    // MARK: - Type Methods

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.version == rhs.version &&
            lhs.previous == rhs.previous &&
            lhs.merkleRoot == rhs.merkleRoot &&
            lhs.time == rhs.time &&
            lhs.target == rhs.target &&
            lhs.nonce == rhs.nonce &&
            lhs.txs == rhs.txs
    }

    static func makeGenesisBlock(consensusParams: ConsensusParams) -> Self {
        let genesisTx = BitcoinTx.makeGenesisTx(blockSubsidy: consensusParams.blockSubsidy)
        let target = consensusParams.genesisBlockTarget
        let genesisBlock = TxBlock(
            context: .init(
                height: 0,
                chainwork: DifficultyTarget.getWork(target),
                status: .full
            ),
            version: 1,
            previous: Data(count: 32),
            merkleRoot: genesisTx.id,
            time: Date(timeIntervalSince1970: TimeInterval(consensusParams.genesisBlockTime)),
            target: target,
            nonce: consensusParams.genesisBlockNonce,
            txs: [genesisTx])
        return genesisBlock
    }
}

package extension TxBlock {

    // MARK: - Initializers

    /// Initialize from serialized raw data.
    init?(_ data: Data) {
        // Check we at least have enough data for block header + empty transactions
        guard data.count >= Self.baseSize else {
            return nil
        }
        var data = data

        // Header
        version = Int(data.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) })
        data = data.dropFirst(MemoryLayout<Int32>.size)
        previous = Data(data.prefix(32).reversed())
        data = data.dropFirst(previous.count)
        merkleRoot = Data(data.prefix(32).reversed())
        data = data.dropFirst(merkleRoot.count)
        let seconds = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        time = Date(timeIntervalSince1970: TimeInterval(seconds))
        data = data.dropFirst(MemoryLayout.size(ofValue: seconds))
        target = Int(data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) })
        data = data.dropFirst(MemoryLayout<UInt32>.size)
        nonce = Int(data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) })
        data = data.dropFirst(MemoryLayout<UInt32>.size)

        guard let txCount = data.varInt else {
            self.txs = []
            return
        }

        guard txCount <= Int.max else { return nil }

        data = data.dropFirst(txCount.varIntSize)
        var txs = [BitcoinTx]()
        for _ in 0 ..< txCount {
            guard let tx = BitcoinTx(data) else {
                return nil
            }
            txs.append(tx)
            data = data.dropFirst(tx.size)
        }
        self.txs = txs
    }

    // MARK: - Computed Properties

    /// Header data
    var headerData: Data {
        var ret = Data(count: Self.baseSize)
        var offset = ret.addBytes(Int32(version))
        offset = ret.addData(previous.reversed(), at: offset)
        offset = ret.addData(merkleRoot.reversed(), at: offset)
        offset = ret.addBytes(UInt32(time.timeIntervalSince1970), at: offset)
        offset = ret.addBytes(UInt32(target), at: offset)
        offset = ret.addBytes(UInt32(nonce), at: offset)
        return ret
    }

    var data: Data {
        var ret = Data(count: size)
        var offset = ret.addData(headerData)
        offset = ret.addData(Data(varInt: UInt64(txs.count)), at: offset)
        ret.addData(Data(txs.map(\.data).joined()), at: offset)
        return ret
    }

    // MARK: - Type Properties

    /// Size of data in bytes.
    static let baseSize = 80

    /// Size of data in bytes.
    var size: Int {
        Self.baseSize + UInt64(txs.count).varIntSize + txs.reduce(0) { $0 + $1.size }
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
        let headerData = headerData + Data(value: nonce)
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
