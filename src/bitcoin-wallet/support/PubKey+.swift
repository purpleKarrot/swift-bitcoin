import Foundation
import BitcoinCrypto

extension PubKey {

    /// Forces the parity to be even-y for uses in ``TaprootAddress``.
    var xOnlyNormalized: Self? {
        if hasEvenY {
            self
        } else if let normalized = PubKey(xOnly: xOnlyData) {
            normalized
        } else {
            .none
        }
    }
}
