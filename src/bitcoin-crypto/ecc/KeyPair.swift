import Foundation
import LibSECP256k1

public struct KeyPair {
    private var implementation: secp256k1_keypair

    public init(_ seckey: SecretKey) {
        var keypair = secp256k1_keypair()
        let seckey = [UInt8](seckey.data)
        guard secp256k1_keypair_create(eccSigningContext, &keypair, seckey) != 0 else {
            preconditionFailure()
        }
        self.implementation = keypair
    }

    public var secretKey: SecretKey {
        var seckey = [UInt8](repeating: 0, count: SecretKey.keyLength)
        withUnsafePointer(to: self.implementation) { keypair in
            let result = secp256k1_keypair_sec(secp256k1_context_static, &seckey, keypair)
            assert(result == 1)
        }
        return SecretKey(implementation: seckey)
    }

    public var publicKey: PublicKey {
        var pubkey = secp256k1_pubkey()
        withUnsafePointer(to: self.implementation) { keypair in
            let result = secp256k1_keypair_pub(secp256k1_context_static, &pubkey, keypair)
            assert(result == 1)
        }
        return PublicKey(implementation: pubkey)
    }

    /// This is the same as calling `publicKey.xOnly`
    public var xOnlyPublicKey: XOnlyPublicKey {
        var xonly = secp256k1_xonly_pubkey()
        let result = withUnsafePointer(to: self.implementation) { keypair in
            secp256k1_keypair_xonly_pub(secp256k1_context_static, &xonly, nil, keypair)
        }
        assert(result == 1)
        return XOnlyPublicKey(implementation: xonly)
    }

    /// There is no such thing as an x-only _secret_ key. This is to differenciate taproot x-only tweaking from BIP32 derivation EC tweaking. This functions is used in BIP341 tests.
    public mutating func tweakXOnly(_ tweak: SecretKey) {
        withUnsafeMutablePointer(to: &self.implementation) { keypair in
            guard secp256k1_keypair_xonly_tweak_add(secp256k1_context_static, keypair, tweak.implementation) != 0 else {
                preconditionFailure()
            }
        }
    }
}
