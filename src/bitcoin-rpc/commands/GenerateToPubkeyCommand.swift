import Foundation
import JSONRPC
import BitcoinCrypto
import BitcoinBlockchain

/// Generates blocks with the coinbase output spending to the provided public key.
public struct GenerateToPubkeyCommand: Sendable {

    public init(blockchainService: BlockchainService) {
        self.blockchainService = blockchainService
    }

    let blockchainService: BlockchainService

    /// Request must contain single public key ( hex string) parameter.
    public func run(_ request: JSONRequest) async throws -> JSONResponse {

        precondition(request.method == Self.method)

        guard case let .list(objects) = RPCObject(request.params), let first = objects.first, case let .string(pubkeyHex) = first else {
            throw RPCError(.invalidParams("pubkey"), description: "Pubkey (hex string) is required.")
        }
        guard let pubkeyData = Data(hex: pubkeyHex), let pubkey = PubKey(compressed: pubkeyData) else {
            throw RPCError(.invalidParams("pubkey"), description: "Pubkey hex encoding or content invalid.")
        }

        await blockchainService.generateTo(pubkey)
        let result = await blockchainService.blocks.last!.idHex

        return .init(id: request.id, result: JSONObject.string(result))
    }

    public static let method = "generate-to"
}
