import Foundation
import JSONRPC
import BitcoinBase
import BitcoinTransport

/// Submits a new (raw) transaction to the mempool. The transaction needs to be both valid and signed for it to be accepted.
public struct SendTransactionCommand: Sendable {

    public init(bitcoinNode: NodeService) {
        self.bitcoinNode = bitcoinNode
    }

    let bitcoinNode: NodeService

    /// Request must contain single transaction (string) parameter.
    public func run(_ request: JSONRequest) async throws {

        precondition(request.method == Self.method)

        guard case let .list(objects) = RPCObject(request.params), let first = objects.first, case let .string(txHex) = first else {
            throw RPCError(.invalidParams("transaction"), description: "Transaction (hex string) is required.")
        }
        guard let txData = Data(hex: txHex), let tx = BitcoinTx(txData) else {
            throw RPCError(.invalidParams("transaction"), description: "Transaction hex encoding or content invalid.")
        }
        do {
            try await bitcoinNode.addTx(tx)
        } catch {
            throw RPCError(.invalidParams("transaction"), description: "Transaction was not accepted into the mempool.")
        }
    }

    public static let method = "send-transaction"
}
