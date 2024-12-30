import Foundation

/// A reference to a specific ``TxOut`` of a particular ``BitcoinTx`` which is stored in a ``TxIn``.
public struct TxOutpoint: Equatable, Hashable, Sendable {
    
    /// Creates a reference to an output of a previous transaction.
    /// - Parameters:
    ///   - tx: The identifier for the previous transaction being referenced.
    ///   - txOut: The index within the previous transaction corresponding to the desired output.
    public init(tx: TxID, txOut: Int) {
        precondition(tx.count == BitcoinTx.idLength)
        self.txID = tx
        self.txOut = txOut
    }

    // The identifier for the transaction containing the referenced output.
    public let txID: TxID

    /// The index of an output in the referenced transaction.
    public let txOut: Int

    public static let coinbase = Self(
        tx: .init(count: BitcoinTx.idLength),
        txOut: 0xffffffff
    )
}

/// Data extensions.
extension TxOutpoint {

    init?(_ data: Data) {
        guard data.count >= Self.size else { return nil }

        var data = data
        let tx = Data(data.prefix(BitcoinTx.idLength).reversed())
        data = data.dropFirst(BitcoinTx.idLength)

        let txOut = Int(data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) })
        self.init(tx: tx, txOut: txOut)
    }

    var data: Data {
        var ret = Data(count: Self.size)
        let offset = ret.addData(txID.reversed())
        ret.addBytes(UInt32(txOut), at: offset)
        return ret
    }

    static let size = BitcoinTx.idLength + MemoryLayout<UInt32>.size
}

