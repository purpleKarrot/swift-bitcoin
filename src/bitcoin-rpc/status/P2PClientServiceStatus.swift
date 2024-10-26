import Foundation

public struct P2PClientServiceStatus: JSONStringConvertible, Sendable {

    public init(running: Bool, connected: Bool, remoteHost: String?, remotePort: Int?, localPort: Int?, overallConnections: Int) {
        self.running = running
        self.connected = connected
        self.remoteHost = remoteHost
        self.remotePort = remotePort
        self.localPort = localPort
        self.overallConnections = overallConnections
    }

    public var index = -1
    let running: Bool
    let connected: Bool
    let remoteHost: String?
    let remotePort: Int?
    let localPort: Int?
    let overallConnections: Int
}
