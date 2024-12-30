import Foundation
import BitcoinBase

/// BIP152: A `PrefilledTransaction` structure is used in `HeaderAndShortIDs` to provide a list of a few transactions explicitly.
public struct PrefilledTx: Equatable {

    public init(index: Int, tx: BitcoinTx) {
        self.index = index
        self.tx = tx
    }

    /// The index into the block at which this transaction is.
    ///
    /// Compact Size, differentially encoded since the last `PrefilledTransaction` in a list.
    ///
    public let index: Int

    /// The transaction which is in the block at index index.
    ///
    /// As encoded in "tx" messages sent in response to getdata `MSG_TX`.
    /// 
    public let tx: BitcoinTx
}

extension PrefilledTx {

    public init?(_ data: Data, previousIndex: Int) {
        guard data.count >= 1 else { return nil }
        var data = data

        guard let indexDiff = data.varInt else { return nil }
        let index = Int(indexDiff) + previousIndex + 1
        self.index = index
        data = data.dropFirst(indexDiff.varIntSize)

        guard let tx = BitcoinTx(data) else { return nil }
        self.tx = tx
        data = data.dropFirst(tx.size)
    }

    func getData(previousIndex: Int?) -> Data {
        var ret = Data(count: size)

        let indexDiff = if let previousIndex {
            index - previousIndex - 1
        } else {
            index
        }
        var offset = ret.addData(Data(varInt: UInt64(indexDiff)))
        offset = ret.addData(tx.data, at: offset)
        return ret
    }

    var size: Int {
        UInt64(index).varIntSize + tx.size
    }
}
