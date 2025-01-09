import Foundation
import BitcoinBase

/// A reference to an unspent transaction output (aka _UTXO_).
struct UnspentOut: Equatable, Sendable {

    let txOut: TxOut
    let height: Int
    let isCoinbase: Bool

    init(_ txOut: TxOut, height: Int = Self.mempoolHeight, isCoinbase: Bool = false) {
        precondition(height > 0 && height <= Self.mempoolHeight && !(isCoinbase && height == Self.mempoolHeight))
        self.txOut = txOut
        self.height = height
        self.isCoinbase = isCoinbase
    }

    var isMempool: Bool {
        height == Self.mempoolHeight
    }
    static let mempoolHeight = 0x7fffffff
}
