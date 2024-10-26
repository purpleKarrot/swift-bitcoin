import Foundation

public struct P2PServiceStatus: JSONStringConvertible, Sendable {

    public init(running: Bool, listening: Bool, host: String?, port: Int?, overallConnections: Int, sessionConnections: Int, activeConnections: Int) {
        self.running = running
        self.listening = listening
        self.host = host
        self.port = port
        self.overallConnections = overallConnections
        self.sessionConnections = sessionConnections
        self.activeConnections = activeConnections
    }

    let running: Bool
    let listening: Bool
    let host: String?
    let port: Int?
    let overallConnections: Int
    let sessionConnections: Int
    let activeConnections: Int
}
