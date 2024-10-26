import Foundation

public struct RPCServiceStatus: JSONStringConvertible, Sendable {

    public init(listening: Bool, host: String, port: Int, overallConnections: Int, activeConnections: Int) {
        self.listening = listening
        self.host = host
        self.port = port
        self.overallConnections = overallConnections
        self.activeConnections = activeConnections
    }

    let listening: Bool
    let host: String?
    let port: Int?
    let overallConnections: Int
    let activeConnections: Int
}
