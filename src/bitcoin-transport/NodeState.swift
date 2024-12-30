import Foundation
import BitcoinBase

public struct NodeState: Sendable {

    public init(feeFilterRate: SatoshiAmount = 1, awaitingHeadersFrom: UUID? = UUID?.none, awaitingHeadersSince: Date? = Date?.none, peers: [UUID : PeerState] = [UUID : PeerState]()) {
        self.feeFilterRate = feeFilterRate
        self.awaitingHeadersFrom = awaitingHeadersFrom
        self.awaitingHeadersSince = awaitingHeadersSince
        self.peers = peers
    }

    /// BIP133: Our current fee filter rate for transactions relayed to us by state.state.peers. Default: 1 satoshi per virtual byte (sat/vbyte).
    public var feeFilterRate: SatoshiAmount // TODO: Allow to be changed via RPC command, #189

    public internal(set) var awaitingHeadersFrom: UUID?
    public internal(set) var awaitingHeadersSince: Date?

    /// Peer information.
    var peers = [UUID : PeerState]()

    @usableFromInline static let initial = Self()
}
