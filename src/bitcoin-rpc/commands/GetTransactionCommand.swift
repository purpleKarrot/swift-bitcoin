import Foundation
import JSONRPC
import BitcoinBase
import BitcoinBlockchain

/// Transaction information including ID, witness ID, inputs and outputs. For each output a raw value is also included in order to facilitate the signing of transactions which require the serialization of previous outputs.
public struct GetTransactionCommand: Sendable {

    internal struct Output: JSONStringConvertible {

        struct Input: Encodable {
            let transaction: String
            let output: Int
        }

        struct Output: Encodable {
            let raw: String
            let amount: BitcoinAmount
            let script: String
        }

        let id: String
        let witnessID: String
        let inputs: [Input]
        let outputs: [Output]
    }

    public init(bitcoinService: BitcoinService) {
        self.bitcoinService = bitcoinService
    }

    let bitcoinService: BitcoinService

    public func run(_ request: JSONRequest) async throws -> JSONResponse {

        precondition(request.method == Self.method)

        guard case let .list(objects) = RPCObject(request.params), let first = objects.first, case let .string(transactionIDHex) = first else {
            throw RPCError(.invalidParams("transactionID"), description: "TransactionID (hex string) is required.")
        }
        guard let transactionID = Data(hex: transactionIDHex), transactionID.count == BitcoinTransaction.idLength else {
            throw RPCError(.invalidParams("transactionID"), description: "TransactionID hex encoding or length is invalid.")
        }
        guard let transaction = await bitcoinService.getTransaction(transactionID) else {
            throw RPCError(.invalidParams("transactionID"), description: "Transaction not found.")
        }
        let inputs = transaction.inputs.map {
            Output.Input(
                transaction: $0.outpoint.transactionID.hex,
                output: $0.outpoint.outputIndex
            )
        }
        let outputs = transaction.outputs.map {
            Output.Output(
                raw: $0.data.hex,
                amount: $0.value,
                script: $0.script.data.hex
            )
        }
        let result = Output(
            id: transaction.id.hex,
            witnessID: transaction.witnessID.hex,
            inputs: inputs,
            outputs: outputs
        )
        return .init(id: request.id, result: JSONObject.string(result.description))
    }

    public static let method = "get-transaction"
}
