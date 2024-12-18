import Foundation
import BitcoinCrypto

extension PublicKey {

    /// Forces the parity to be even-y for uses in ``TaprootAddress``.
    var xOnlyNormalized: Self? {
        if hasEvenY {
            self
        } else if let normalized = PublicKey(xOnly: xOnly.data) {
            normalized
        } else {
            .none
        }
    }
}
