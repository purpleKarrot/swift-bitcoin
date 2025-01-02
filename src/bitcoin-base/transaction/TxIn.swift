import Foundation

/// A single input belonging to a ``BitcoinTx``.
public struct TxIn: Equatable, Sendable {

    // MARK: - Initializers

    /// Constructs a transaction input.
    /// - Parameters:
    ///   - outpoint: The output that this input is spending.
    ///   - sequence: This input's sequence number.
    ///   - script: Optional script to unlock the referenced output.
    ///   - witness: Optional witness data for this input. See BIP141 for more information.
    public init(outpoint: TxOutpoint, sequence: TxSequence = .final, script: BitcoinScript = .empty, /* BIP141 */ witness: TxWitness? = .none) {
        self.outpoint = outpoint
        self.sequence = sequence
        self.script = script

        // BIP141
        self.witness = witness
    }

    // MARK: - Instance Properties

    /// A reference to a previously unspent output of a prior transaction.
    public var outpoint: TxOutpoint

    /// The sequence number for this input.
    public var sequence: TxSequence

    /// The script that unlocks the output associated with this input.
    public var script: BitcoinScript

    /// BIP141 - Segregated witness data associated with this input.
    public var witness: TxWitness?
}

/// Data extensions.
extension TxIn {

    init?(_ data: Data) {
        var data = data
        guard let outpoint = TxOutpoint(data) else { return nil }
        data = data.dropFirst(TxOutpoint.size)

        guard let script = BitcoinScript(prefixedData: data) else { return nil }
        data = data.dropFirst(script.prefixedSize)

        guard let sequence = TxSequence(data) else { return nil }

        self.init(outpoint: outpoint, sequence: sequence, script: script)
    }

    // MARK: - Instance Properties

    /// Used by ``BitcoinTx/data``.
    var data: Data {
        var ret = Data(count: size)
        var offset = ret.addData(outpoint.data)
        offset = ret.addData(script.prefixedData, at: offset)
        ret.addData(sequence.data, at: offset)
        return ret
    }

    /// Used by ``BitcoinTx/size``.
    var size: Int {
        TxOutpoint.size + script.prefixedSize + TxSequence.size
    }
}
