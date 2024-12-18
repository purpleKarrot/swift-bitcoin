//
//  XOnlyPublicKey.swift
//  swift-bitcoin
//
//  Created by Daniel Pfeifer on 18.12.2024.
//

import Foundation
import LibSECP256k1

public struct XOnlyPublicKey: Codable, CustomStringConvertible, HexRepresentable {
    private var implementation: secp256k1_xonly_pubkey

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

    package func checkTweak(_ tweakData: Data, outputKey: PublicKey) -> Bool {
        let outputKeyBytes = [UInt8](outputKey.xOnly.data)
        let tweakBytes = [UInt8](tweakData)

        let parity = Int32(outputKey.hasOddY ? 1 : 0)
        return withUnsafePointer(to: self.implementation) { xonly in
            secp256k1_xonly_pubkey_tweak_add_check(secp256k1_context_static, outputKeyBytes, parity, xonly, tweakBytes) != 0
        }
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
    public static func + (lhs: XOnlyPublicKey, rhs: SecretKey) -> PublicKey {
        var pubkey = secp256k1_pubkey()
        let seckey = rhs.implementation
        let result = withUnsafePointer(to: lhs.implementation) { xonly in
            secp256k1_xonly_pubkey_tweak_add(secp256k1_context_static, &pubkey, xonly, seckey)
        }
        guard result != 0 else {
            preconditionFailure()
        }
        return PublicKey(implementation: pubkey)
    }
}
