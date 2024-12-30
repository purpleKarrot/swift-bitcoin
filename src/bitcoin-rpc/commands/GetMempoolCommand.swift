import Foundation
import JSONRPC
import BitcoinBase
import BitcoinBlockchain

/// Summary of current mempool information including a list of transaction IDs.
public struct GetMempoolCommand: Sendable {

    internal struct Output: JSONStringConvertible {
        let size: Int
        let txs: [String]
    }

    public init(blockchainService: BlockchainService) {
        self.blockchainService = blockchainService
    }

    let blockchainService: BlockchainService

    public func run(_ request: JSONRequest) async -> JSONResponse {

        precondition(request.method == Self.method)

        let mempool = await blockchainService.mempool
        let result = Output(
            size: mempool.count,
            txs: mempool.map(\.id.hex)
        )
        return .init(id: request.id, result: JSONObject.string(result.description))
    }

    public static let method = "get-mempool"
}
