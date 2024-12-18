import Foundation
import LibSECP256k1

/// Elliptic curve SECP256K1 secret key.
public struct SecretKey: Equatable, CustomStringConvertible, HexRepresentable {
    var implementation: [UInt8]

    init(implementation: [UInt8]) {
        self.implementation = implementation
    }

    /// Uses global secp256k1 signing context.
    public init() {
        var bytes: [UInt8]
        repeat {
            bytes = getRandBytes(32)
        } while secp256k1_ec_seckey_verify(eccSigningContext, bytes) == 0
        self.implementation = bytes
    }

    /// Uses global secp256k1 signing context.
    public init?(_ data: Data) {
        guard data.count == Self.keyLength else {
            return nil
        }
        let bytes = [UInt8](data)
        guard secp256k1_ec_seckey_verify(eccSigningContext, bytes) != 0 else {
            return nil
        }
        self.implementation = bytes
    }

    public var data: Data { .init(implementation) }

    public var publicKey: PublicKey { .init(self) }

    package var xOnlyPublicKey: PublicKey {
        .init(self, requireEvenY: true)
    }

    public func sign(_ message: String, signatureType: SignatureType = .ecdsa, recoverCompressedKeys: Bool = true) -> Signature? {
        .init(message: message, secretKey: self, type: signatureType, recoverCompressedKeys: recoverCompressedKeys)
    }

    public func sign(hash: Data, signatureType: SignatureType = .ecdsa, recoverCompressedKeys: Bool = true) -> Signature {
        .init(hash: hash, secretKey: self, type: signatureType, recoverCompressedKeys: recoverCompressedKeys)
    }

    /// There is no such thing as an x-only _secret_ key. This is to differenciate taproot x-only tweaking from BIP32 derivation EC tweaking. This functions is used in BIP341 tests.
    public func tweakXOnly(_ tweak: Data) -> SecretKey {
        var keypair = KeyPair(self)
        keypair.tweakXOnly(SecretKey(tweak)!)
        return keypair.secretKey
    }

    public static let keyLength = 32
}

extension SecretKey {
    public static func += (lhs: inout SecretKey, rhs: SecretKey) {
        guard secp256k1_ec_seckey_tweak_add(secp256k1_context_static, &lhs.implementation, rhs.implementation) != 0 else {
            preconditionFailure()
        }
    }

    public static func + (lhs: SecretKey, rhs: SecretKey) -> SecretKey {
        var copy = lhs
        copy += rhs
        return copy
    }
}
