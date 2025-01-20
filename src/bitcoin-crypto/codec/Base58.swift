import Foundation

/// Length of checksum appended to Base58Check encoded strings.
private let checksumLength = 4

private let alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".data(using: .ascii)!

/// Produces checksumed Base58 strings used for legacy Bitcoin addresses.
public struct Base58Encoder {

    public init(withChecksum: Bool = true) {
        self.withChecksum = withChecksum
    }

    public let withChecksum: Bool

    public func encode(_ data: Data) -> String {
        return base58Encode(withChecksum ? data + calculateChecksum(data) : data)
    }
}

/// Decodes raw data from Base58 strings.
public struct Base58Decoder {

    public init(withChecksum: Bool = true) {
        self.withChecksum = withChecksum
    }

    public let withChecksum: Bool

    public func decode(_ string: String) -> Data? {
        guard let data = base58Decode(string) else {
            return .none
        }
        guard withChecksum else {
            return data
        }
        let checksum = data.suffix(checksumLength)
        let payload = data.prefix(upTo: data.count - checksumLength)
        let expectedChecksum = calculateChecksum(payload)
        guard checksum == expectedChecksum else {
            return .none
        }
        return payload
    }
}

private func base58Encode(_ bytes: Data) -> String {
    var b58 = Data(count: bytes.count * 138 / 100 + 1)
    var length = 0

    for byte in bytes {
        var i = 0
        var carry = UInt(byte)
        while i < b58.count && (carry != 0 || i < length) {
            let idx = b58.count - 1 - i
            carry += 256 * UInt(b58[idx])
            b58[idx] = UInt8(carry % 58)
            carry /= 58
            i += 1
        }

        assert(carry == 0)
        length = i
    }

    let data = Data(count: bytes.prefix { $0 == 0 }.count) + b58.suffix(length)

    // Force unwrap as the given alphabet will always decode to UTF8.
    return String(bytes: data.map { alphabet[Int($0)] }, encoding: .utf8)!
}

private func base58Decode(_ string: String) -> Data? {
    var b256 = Data(count: string.count * 733 / 1000 + 1)
    var length = 0

    guard let byteString = string.data(using: .ascii) else {
        return nil
    }

    for char in byteString {
        guard let alphabetIndex = alphabet.firstIndex(of: char) else {
            return .none
        }

        var i = 0
        var carry = UInt(alphabetIndex)
        while i < b256.count && (carry != 0 || i < length) {
            let idx = b256.count - 1 - i
            carry += 58 * UInt(b256[idx])
            b256[idx] = UInt8(carry % 256)
            carry /= 256
            i += 1
        }

        assert(carry == 0)
        length = i
    }

    let bytes = b256.suffix(length)
    return .init(count: byteString.prefix { $0 == alphabet[0] }.count) + bytes
}

private func calculateChecksum(_ data: Data) -> Data {
    Data(Hash256.hash(data: data)).prefix(checksumLength)
}
