import ECCHelper  // For `secp256k1_ec_pubkey_combine2()`
import Foundation
import LibSECP256k1

/// Elliptic curve SECP256K1 public key.
public struct PublicKey: Sendable, CustomStringConvertible, Codable, HexRepresentable {
    var implementation: secp256k1_pubkey

    init(implementation: secp256k1_pubkey) {
        self.implementation = implementation
    }

    public init?(_ hex: String, skipCheck: Bool = false) {
        guard let data = Data(hex: hex) else {
            return nil
        }
        self.init(data)
    }

    public init?(xOnly data: Data, hasEvenY: Bool = true) {
        guard data.count == XOnlyPublicKey.keyLength else {
            return nil
        }
        self.init([hasEvenY ? Self.tagEven: Self.tagOdd] + data)
    }

    /// BIP143: Checks that the public key is compressed.
    public init?<D: DataProtocol>(compressed data: D, skipCheck: Bool = false) {
        guard data.count == PublicKey.compressedLength &&
            (data.first! == Self.tagEven || data.first! == Self.tagOdd)
        else { return nil }
        self.init(Data(data))
    }

    /// Used mainly for Satoshi's hard-coded key (genesis block).
    /// Checks that the public key is uncompressed.
    public init?<D: DataProtocol>(uncompressed data: D, skipCheck: Bool = false)
    {
        guard data.count == PublicKey.uncompressedLength && data.first! == Self.tagUncompressed
        else { return nil }
        self.init(Data(data))
    }

    /// Data will be checked to be either compressed or uncompressed public key encoding.
    public init?<D: DataProtocol>(_ data: D) {
        let bytes = [UInt8](data)
        var pubkey: secp256k1_pubkey = .init()
        let result = withUnsafeMutablePointer(to: &pubkey) { pubkey in
            secp256k1_ec_pubkey_parse(secp256k1_context_static, pubkey, bytes, bytes.count)
        }
        if result == 0 {
            return nil
        }
        self.init(implementation: pubkey)
    }

    public var data: Data {
        self.compressedData
    }

    public var uncompressedData: Data {
        self.serialize(length: PublicKey.uncompressedLength, flags: UInt32(SECP256K1_EC_UNCOMPRESSED))
    }

    public var compressedData: Data {
        self.serialize(length: PublicKey.compressedLength, flags: UInt32(SECP256K1_EC_COMPRESSED))
    }

    private func serialize(length: Int, flags: UInt32) -> Data {
        var len = length
        var bytes = [UInt8](repeating: 0, count: length)
        let result = withUnsafePointer(to: self.implementation) { pubkey in
            secp256k1_ec_pubkey_serialize(secp256k1_context_static, &bytes, &len, pubkey, flags)
        }
        assert(result != 0)
        assert(len == length)
        return Data(bytes)
    }

    public var xOnly: XOnlyPublicKey {
        var xonly = secp256k1_xonly_pubkey()
        let result = withUnsafePointer(to: self.implementation) { pubkey in
            secp256k1_xonly_pubkey_from_pubkey(secp256k1_context_static, &xonly, nil, pubkey)
        }
        assert(result != 0)
        return .init(implementation: xonly)
    }

    public func matches(_ secretKey: SecretKey) -> Bool {
        self == secretKey.publicKey
    }

    public func verify(_ signature: Signature, for message: String) -> Bool {
        signature.verify(message: message, publicKey: self)
    }

    public var hasEvenY: Bool {
        if data.count == PublicKey.compressedLength {
            data.first! == Self.tagEven
        } else {
            data.last! & 1 == 0 // we look at the least significant bit of the y coordinate
        }
    }

    public var hasOddY: Bool {
        if data.count == PublicKey.compressedLength {
            data.first! == Self.tagOdd
        } else {
            data.last! & 1 == 1
        }
    }

    public static let uncompressedLength = 65
    public static let compressedLength = 33

    public static let tagEven = UInt8(SECP256K1_TAG_PUBKEY_EVEN)
    public static let tagOdd = UInt8(SECP256K1_TAG_PUBKEY_ODD)
    public static let tagUncompressed = UInt8(SECP256K1_TAG_PUBKEY_UNCOMPRESSED)

    public static let satoshi = PublicKey(uncompressed: [0x04, 0x67, 0x8a, 0xfd, 0xb0, 0xfe, 0x55, 0x48, 0x27, 0x19, 0x67, 0xf1, 0xa6, 0x71, 0x30, 0xb7, 0x10, 0x5c, 0xd6, 0xa8, 0x28, 0xe0, 0x39, 0x09, 0xa6, 0x79, 0x62, 0xe0, 0xea, 0x1f, 0x61, 0xde, 0xb6, 0x49, 0xf6, 0xbc, 0x3f, 0x4c, 0xef, 0x38, 0xc4, 0xf3, 0x55, 0x04, 0xe5, 0x1e, 0xc1, 0x12, 0xde, 0x5c, 0x38, 0x4d, 0xf7, 0xba, 0x0b, 0x8d, 0x57, 0x8a, 0x4c, 0x70, 0x2b, 0x6b, 0xf1, 0x1d, 0x5f])!
}

// MARK: Comparable
extension PublicKey: Comparable {
    public static func < (lhs: PublicKey, rhs: PublicKey) -> Bool {
        cmp(lhs, rhs) < 0
    }

    public static func == (lhs: PublicKey, rhs: PublicKey) -> Bool {
        cmp(lhs, rhs) == 0
    }

    private static func cmp(_ lhs: PublicKey, _ rhs: PublicKey) -> Int32 {
        withUnsafePointer(to: lhs.implementation) { lhs in
            withUnsafePointer(to: rhs.implementation) { rhs in
                secp256k1_ec_pubkey_cmp(secp256k1_context_static, lhs, rhs)
            }
        }
    }
}

// MARK: Operators
extension PublicKey {
    public static prefix func - (arg: PublicKey) -> PublicKey {
        var copy = arg
        let result = withUnsafeMutablePointer(to: &copy.implementation) { pubkey in
            secp256k1_ec_pubkey_negate(secp256k1_context_static, pubkey)
        }
        assert(result != 0)
        return copy
    }

    public static func + (lhs: PublicKey, rhs: PublicKey) -> PublicKey {
        var combined: secp256k1_pubkey = .init()
        withUnsafePointer(to: lhs.implementation) { lhs in
            let result = withUnsafePointer(to: rhs.implementation) { rhs in
                secp256k1_ec_pubkey_combine2(secp256k1_context_static, &combined, lhs, rhs)
            }
            assert(result != 0)
        }
        return PublicKey(implementation: combined)
    }

    public static func - (lhs: PublicKey, rhs: PublicKey) -> PublicKey {
        lhs + (-rhs)
    }

    public static func += (lhs: inout PublicKey, rhs: SecretKey) {
        withUnsafeMutablePointer(to: &lhs.implementation) { pubkey in
            let seckey = [UInt8](rhs.data)
            let result = secp256k1_ec_pubkey_tweak_add(secp256k1_context_static, pubkey, seckey)
            assert(result != 0)
        }
    }

    public static func *= (lhs: inout PublicKey, rhs: SecretKey) {
        withUnsafeMutablePointer(to: &lhs.implementation) { pubkey in
            let seckey = [UInt8](rhs.data)
            let result = secp256k1_ec_pubkey_tweak_mul(secp256k1_context_static, pubkey, seckey)
            assert(result != 0)
        }
    }

    public static func + (lhs: PublicKey, rhs: SecretKey) -> PublicKey {
        var copy = lhs
        copy += rhs
        return copy
    }

    public static func * (lhs: PublicKey, rhs: SecretKey) -> PublicKey {
        var copy = lhs
        copy *= rhs
        return copy
    }
}
