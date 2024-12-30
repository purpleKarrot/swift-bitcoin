import Foundation

/// A reference to an unspent transaction output (aka _UTXO_).
public struct UnspentOut: Equatable {
    let output: TxOut
    let height: Int
    let isCoinbase: Bool
}
