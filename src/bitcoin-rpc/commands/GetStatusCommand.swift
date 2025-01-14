import Foundation
import JSONRPC
import BitcoinBase
import BitcoinBlockchain

/// Status of the RPC and Peer-to-Peer services.
public struct GetStatusCommand: Sendable {

    public init(rpcStatus: RPCServiceStatus, p2pStatus: P2PServiceStatus, p2pClientStatus: [P2PClientStatus]) {
        self.rpcStatus = rpcStatus
        self.p2pStatus = p2pStatus
        self.p2pClientStatus = p2pClientStatus
    }

    let rpcStatus: RPCServiceStatus
    let p2pStatus: P2PServiceStatus
    let p2pClientStatus: [P2PClientStatus]

    public func run(_ request: JSONRequest) async -> JSONResponse {

        precondition(request.method == Self.method)

        let result = """
        RPC server status:
        \(rpcStatus)

        P2P server status:
        \(p2pStatus)

        P2P clients' status:
        \(p2pClientStatus.map(\.description).joined(separator: "\n\n"))
        """

        return .init(id: request.id, result: JSONObject.string(result.description))
    }

    public static let method = "status"
}
