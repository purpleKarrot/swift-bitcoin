//
//  XOnlyPublicKey.swift
//  swift-bitcoin
//
//  Created by Daniel Pfeifer on 18.12.2024.
//

import Foundation
import LibSECP256k1

public struct XOnlyPublicKey: Codable, CustomStringConvertible, HexRepresentable {
    var implementation: secp256k1_xonly_pubkey

    init (implementation: secp256k1_xonly_pubkey) {
        self.implementation = implementation
    }

    public init?(_ data: Data) {
        guard data.count == Self.keyLength else { return nil }
        let bytes = [UInt8](data)
        var xonly = secp256k1_xonly_pubkey()
        guard secp256k1_xonly_pubkey_parse(secp256k1_context_static, &xonly, bytes) != 0 else { return nil }
        self.implementation = xonly
    }

    public var data: Data {
        var bytes = [UInt8](repeating: 0, count: Self.keyLength)
        let result = withUnsafePointer(to: self.implementation) { xonly in
            secp256k1_xonly_pubkey_serialize(secp256k1_context_static, &bytes, xonly)
        }
        assert(result == 1)
        return Data(bytes)
    }

    public static let keyLength = 32
}

// MARK: Comparable
extension XOnlyPublicKey: Comparable {
    public static func < (lhs: XOnlyPublicKey, rhs: XOnlyPublicKey) -> Bool {
        cmp(lhs, rhs) < 0
    }

    public static func == (lhs: XOnlyPublicKey, rhs: XOnlyPublicKey) -> Bool {
        cmp(lhs, rhs) == 0
    }

    private static func cmp(_ lhs: XOnlyPublicKey, _ rhs: XOnlyPublicKey) -> Int32
    {
        withUnsafePointer(to: lhs.implementation) { lhs in
            withUnsafePointer(to: rhs.implementation) { rhs in
                secp256k1_xonly_pubkey_cmp(secp256k1_context_static, lhs, rhs)
            }
        }
    }
}

// MARK: Operators
extension XOnlyPublicKey {
    public static func + (lhs: XOnlyPublicKey, rhs: SecretKey) -> XOnlyPublicKeyTweakAddExpression {
        .init(xonly: lhs, seckey: rhs)
    }
}

public struct XOnlyPublicKeyTweakAddExpression {
    public let xonly: XOnlyPublicKey
    public let seckey: SecretKey

    var publicKey: PublicKey {
        var pubkey = secp256k1_pubkey()
        let seckey = self.seckey.implementation
        withUnsafePointer(to: self.xonly.implementation) { xonly in
            guard secp256k1_xonly_pubkey_tweak_add(secp256k1_context_static, &pubkey, xonly, seckey) != 0 else {
                preconditionFailure()
            }
        }

        return .init(implementation: pubkey)
    }

    public static func == (lhs: XOnlyPublicKeyTweakAddExpression, rhs: PublicKey) -> Bool {
        var parity: Int32 = -1
        var tweaked = secp256k1_xonly_pubkey()
        withUnsafePointer(to: rhs.implementation) { pubkey in
            guard secp256k1_xonly_pubkey_from_pubkey(secp256k1_context_static, &tweaked, &parity, pubkey) != 0 else {
                preconditionFailure()
            }
        }

        var tweakedPubkey32 = [UInt8](repeating: 0, count: XOnlyPublicKey.keyLength)
        guard secp256k1_xonly_pubkey_serialize(secp256k1_context_static, &tweakedPubkey32, &tweaked) != 0 else {
            preconditionFailure()
        }

        let tweak32 = lhs.seckey.implementation
        return withUnsafePointer(to: lhs.xonly.implementation) { xonly in
            secp256k1_xonly_pubkey_tweak_add_check(secp256k1_context_static, tweakedPubkey32, parity, xonly, tweak32) != 0
        }
    }
}

extension PublicKey {
    public init(_ expr: XOnlyPublicKeyTweakAddExpression) { self = expr.publicKey }
}
