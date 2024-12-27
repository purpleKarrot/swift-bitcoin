import Foundation
import BitcoinCrypto

public typealias BlockID = Data

/// A block's header.
public struct BlockHeader: Equatable, Sendable {

    // MARK: - Initializers

    public init(version: Int = 2, previous: Data, merkleRoot: Data, time: Date = .now, target: Int, nonce: Int = 0) {
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
    }

    // MARK: - Instance Properties

    public let version: Int
    public let previous: Data
    public let merkleRoot: Data
    public let time: Date

    /// Difficulty bits.
    public let target: Int

    public let nonce: Int

    // MARK: - Computed Properties

    public var hash: Data {
        Data(Hash256.hash(data: data))
    }

    public var id: BlockID {
        Data(hash.reversed())
    }

    public var idHex: String {
        id.hex
    }

    var work: DifficultyTarget {
        var neg: Bool = true
        var over: Bool = true
        let target = DifficultyTarget(compact: target, negative: &neg, overflow: &over)
        guard !neg && !over && !target.isZero else {
            fatalError()
        }

        // We need to compute 2**256 / (bnTarget+1), but we can't represent 2**256
        // as it's too large for an arith_uint256. However, as 2**256 is at least as large
        // as bnTarget+1, it is equal to ((2**256 - bnTarget - 1) / (bnTarget+1)) + 1,
        // or ~bnTarget / (bnTarget+1) + 1.
        return (~target / (target + 1)) + 1;
    }

    // MARK: - Instance Methods

    // MARK: - Type Properties

    public static let idLength = Hash256.Digest.byteCount

    // MARK: - Type Methods

    // No type methods yet.
}

extension BlockHeader {

    // MARK: - Initializers

    /// Initialize from serialized raw data.
    public init?(_ data: Data) {
        guard data.count >= Self.size else {
            return nil
        }
        var data = data
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
    }

    // MARK: - Computed Properties

    public var data: Data {
        var ret = Data(count: Self.size)
        var offset = ret.addBytes(Int32(version))
        offset = ret.addData(previous.reversed(), at: offset)
        offset = ret.addData(merkleRoot.reversed(), at: offset)
        offset = ret.addBytes(UInt32(time.timeIntervalSince1970), at: offset)
        offset = ret.addBytes(UInt32(target), at: offset)
        offset = ret.addBytes(UInt32(nonce), at: offset)
        return ret
    }

    // MARK: - Type Properties

    /// Size of data in bytes.
    public static let size = 80
}
