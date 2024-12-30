import Foundation
import BitcoinBase

public struct NodeConfig : Sendable {

    public init(network: NodeNetwork = .regtest, version: ProtocolVersion = .latest, services: ProtocolServices = .all, maxInTransitBlocks: Int = 16, feeFilterRate: SatoshiAmount = 1) {
        self.network = network
        self.version = version
        self.services = services
        self.maxInTransitBlocks = maxInTransitBlocks
        self.feeFilterRate = feeFilterRate
    }

    /// The type of bitcoin network this node is part of.
    public let network: NodeNetwork

    public let version: ProtocolVersion
    public let services: ProtocolServices

    public let maxInTransitBlocks: Int
    public let feeFilterRate: SatoshiAmount

    @usableFromInline static let `default` = Self()
}
