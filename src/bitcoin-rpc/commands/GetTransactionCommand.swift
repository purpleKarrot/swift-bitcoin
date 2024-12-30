import Foundation
import JSONRPC
import BitcoinBase
import BitcoinBlockchain

/// Transaction information including ID, witness ID, inputs and outputs. For each output a raw value is also included in order to facilitate the signing of transactions which require the serialization of previous outputs.
public struct GetTransactionCommand: Sendable {

    internal struct Output: JSONStringConvertible {

        struct Input: Encodable {
            let tx: String
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

    public init(blockchainService: BlockchainService) {
        self.blockchainService = blockchainService
    }

    let blockchainService: BlockchainService

    public func run(_ request: JSONRequest) async throws -> JSONResponse {

        precondition(request.method == Self.method)

        guard case let .list(objects) = RPCObject(request.params), let first = objects.first, case let .string(txIDHex) = first else {
            throw RPCError(.invalidParams("txID"), description: "TxID (hex string) is required.")
        }
        guard let txID = Data(hex: txIDHex), txID.count == BitcoinTx.idLength else {
            throw RPCError(.invalidParams("txID"), description: "TxID hex encoding or length is invalid.")
        }
        guard let tx = await blockchainService.getTx(txID) else {
            throw RPCError(.invalidParams("txID"), description: "Transaction not found.")
        }
        let inputs = tx.inputs.map {
            Output.Input(
                tx: $0.outpoint.txID.hex,
                output: $0.outpoint.outputIndex
            )
        }
        let outputs = tx.outputs.map {
            Output.Output(
                raw: $0.data.hex,
                amount: $0.value,
                script: $0.script.data.hex
            )
        }
        let result = Output(
            id: tx.id.hex,
            witnessID: tx.witnessID.hex,
            inputs: inputs,
            outputs: outputs
        )
        return .init(id: request.id, result: JSONObject.string(result.description))
    }

    public static let method = "get-transaction"
}
