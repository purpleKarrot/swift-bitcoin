import Foundation
import JSONRPC
import BitcoinBase
import BitcoinBlockchain

/// Block information by block ID. Includes a reference to the previous block and a list of transaction IDs.
public struct GetBlockCommand: Sendable {

    internal struct Output: JSONStringConvertible {
        let id: String
        let previous: String
        let txs: [String]
    }

    public init(blockchainService: BlockchainService) {
        self.blockchainService = blockchainService
    }

    let blockchainService: BlockchainService

    public func run(_ request: JSONRequest) async throws -> JSONResponse {

        precondition(request.method == Self.method)

        guard case let .list(objects) = RPCObject(request.params), let first = objects.first, case let .string(blockIDHex) = first else {
            throw RPCError(.invalidParams("blockID"), description: "BlockID (hex string) is required.")
        }
        guard let blockID = Data(hex: blockIDHex), blockID.count == TxBlock.idLength else {
            throw RPCError(.invalidParams("blockID"), description: "BlockID hex encoding or length is invalid.")
        }

        guard let block = await blockchainService.getBlock(blockID) else {
            throw RPCError(.invalidParams("blockID"), description: "Block not found.")
        }
        let txs = block.txs.map { $0.id.hex }

        let result = Output(
            id: block.idHex,
            previous: block.previous.hex,
            txs: txs
        )
        return .init(id: request.id, result: JSONObject.string(result.description))
    }

    public static let method = "get-block"
}
