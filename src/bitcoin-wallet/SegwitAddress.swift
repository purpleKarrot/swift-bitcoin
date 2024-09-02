import Foundation
import BitcoinCrypto
import BitcoinBase

public struct SegwitAddress: CustomStringConvertible {

    public let network: WalletNetwork
    public let hash: Data

    public init(_ publicKey: PublicKey, network: WalletNetwork = .main) {
        self.network = network
        hash = Data(Hash160.hash(data: publicKey.data))
    }

    public init(_ script: BitcoinScript, network: WalletNetwork = .main) {
        precondition(script.sigVersion == .witnessV0)
        self.network = network
        hash = Data(SHA256.hash(data: script.data))
    }

    public var description: String {
        try! SegwitAddressEncoder(hrp: network.bech32HRP, version: 0).encode(hash)
    }
}
