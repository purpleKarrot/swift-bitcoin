import Foundation
import JSONRPC
import BitcoinCrypto
import BitcoinBlockchain

/// Generates blocks with the coinbase output spending to the provided public key.
public struct GenerateToPublicKeyCommand: Sendable {

    public init(blockchainService: BlockchainService) {
        self.blockchainService = blockchainService
    }

    let blockchainService: BlockchainService

    /// Request must contain single public key ( hex string) parameter.
    public func run(_ request: JSONRequest) async throws -> JSONResponse {

        precondition(request.method == Self.method)

        guard case let .list(objects) = RPCObject(request.params), let first = objects.first, case let .string(publicKeyHex) = first else {
            throw RPCError(.invalidParams("publicKey"), description: "PublicKey (hex string) is required.")
        }
        guard let publicKeyData = Data(hex: publicKeyHex), let publicKey = PublicKey(compressed: publicKeyData) else {
            throw RPCError(.invalidParams("publicKey"), description: "PublicKey hex encoding or content invalid.")
        }

        await blockchainService.generateTo(publicKey)
        let result = await blockchainService.blocks.last!.header.idHex

        return .init(id: request.id, result: JSONObject.string(result))
    }

    public static let method = "generate-to"
}
