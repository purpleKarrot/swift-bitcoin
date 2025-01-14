import Foundation
import BitcoinBase

public struct NodeConfig : Sendable {

    public init(network: NodeNetwork = .regtest, version: ProtocolVersion = .latest, services: ProtocolServices = .all, maxInTransitBlocks: Int = 16, feeFilterRate: SatoshiAmount = 1, highBandwidthCompactBlocks: Bool = false) {
        self.network = network
        self.version = version
        self.services = services
        self.maxInTransitBlocks = maxInTransitBlocks
        self.feeFilterRate = feeFilterRate
        self.highBandwidthCompactBlocks = highBandwidthCompactBlocks
    }

    /// The type of bitcoin network this node is part of.
    public let network: NodeNetwork

    public let version: ProtocolVersion
    public let services: ProtocolServices

    public let maxInTransitBlocks: Int
    public let feeFilterRate: SatoshiAmount
    public let highBandwidthCompactBlocks: Bool

    @usableFromInline static let `default` = Self()
}
