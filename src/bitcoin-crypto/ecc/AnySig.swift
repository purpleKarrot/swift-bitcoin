import Foundation
import LibSECP256k1
import ECCHelper // For `ecdsa_signature_parse_der_lax()`

/// Supported types of signature and signature encodings.
public enum SigType: Equatable, Sendable {
    case ecdsa, compact, recoverable, schnorr
}

/// Elliptic curve SECP256K1 signature supporting both ECDSA and Schnorr algorithms.
public struct AnySig: Equatable, Sendable, CustomStringConvertible {

    public init?(message: String, secretKey: SecretKey, type: SigType = .ecdsa, recoverCompressedKeys: Bool = true) {
        guard let messageData = message.data(using: .utf8) else {
            return nil
        }
        self.init(messageData: messageData, secretKey: secretKey, type: type, recoverCompressedKeys: recoverCompressedKeys)
    }

    public init(messageData: Data, secretKey: SecretKey, type: SigType = .ecdsa, additionalEntropy: Data? = .none, recoverCompressedKeys: Bool = true) {
        self.init(hash: getMessageHash(messageData: messageData, type: type), secretKey: secretKey, type: type, additionalEntropy: additionalEntropy, recoverCompressedKeys: recoverCompressedKeys)
    }

    public init(hash: Data, secretKey: SecretKey, type: SigType = .ecdsa, additionalEntropy: Data? = .none, recoverCompressedKeys: Bool = true) {
        precondition(hash.count == Self.hashLength)
        switch type {
        case .ecdsa:
            data = signECDSA(hash: hash, secretKey: secretKey)
        case .compact:
            data = signCompact(hash: hash, secretKey: secretKey)
        case .recoverable:
            data = signRecoverable(hash: hash, secretKey: secretKey, compressedPubkeys: recoverCompressedKeys)
            assert(data.count == Self.recoverableSignatureLength)
        case .schnorr:
            data = signSchnorr(hash: hash, secretKey: secretKey, additionalEntropy: additionalEntropy)
            assert(data.count == Self.schnorrSignatureLength)
        }
        self.type = type
    }

    public init?(_ hex: String, type: SigType = .ecdsa) {
        guard let data = Data(hex: hex) else {
            return nil
        }
        self.init(data, type: type)
    }

    public init?(_ data: Data, type: SigType = .ecdsa) {
        switch type {
        case .ecdsa:
            guard data.count >= Self.compactSignatureLength && data.count <= Self.ecdsaSignatureMaxLength else {
                return nil
            }
        case .compact:
            guard data.count == Self.compactSignatureLength else {
                return nil // This check covers high R because there would be 1 extra byte.
            }
            guard internalIsLowS(compactSignatureData: data) else {
                return nil
            }
        case .recoverable:
            guard data.count == Self.recoverableSignatureLength else {
                return nil
            }
        case .schnorr:
            guard data.count == Self.schnorrSignatureLength else {
                return nil
            }
        }
        self.data = data
        self.type = type
    }

    public let data: Data
    public let type: SigType

    public var description: String {
        data.hex
    }

    public var base64: String {
        data.base64EncodedString()
    }

    public var isLowS: Bool {
        switch type {
        case .ecdsa:
            internalIsLowS(laxSignatureData: data)
        case .compact:
            internalIsLowS(compactSignatureData: data)
        default:
            preconditionFailure()
        }
    }

    public func verify(message: String, pubkey: PubKey) -> Bool {
        guard let messageData = message.data(using: .utf8) else {
            return false
        }
        return verify(messageData: messageData, pubkey: pubkey)
    }

    public func verify(messageData: Data, pubkey: PubKey) -> Bool {
        verify(hash: getMessageHash(messageData: messageData, type: type), pubkey: pubkey)
    }

    public func verify(hash: Data, pubkey: PubKey) -> Bool {
        assert(hash.count == Self.hashLength)
        switch type {
        case .ecdsa:
            return verifyECDSA(sigData: data, hash: hash, pubkey: pubkey)
        case .compact:
            return verifyCompact(sigData: data, hash: hash, pubkey: pubkey)
        case .recoverable:
            return internalRecoverPubkey(sigData: data, hash: hash) != .none
        case .schnorr:
            return verifySchnorr(sigData: data, hash: hash, pubkey: pubkey)
        }
    }

    public func recoverPubkey(from message: String) -> PubKey? {
        guard let messageData = message.data(using: .utf8) else {
            return .none
        }
        return recoverPubkey(messageData: messageData)
    }

    public func recoverPubkey(messageData: Data) -> PubKey? {
        precondition(type == .recoverable)
        guard let pubkeyData = internalRecoverPubkey(sigData: data, hash: getMessageHash(messageData: messageData, type: .recoverable)) else {
            return .none
        }
        return PubKey(pubkeyData)
    }

    /// A canonical signature exists of: <30> <total len> <02> <len R> <R> <02> <len S> <S> <hashtype>
    /// Where R and S are not negative (their first byte has its highest bit not set), and not
    /// excessively padded (do not start with a 0 byte, unless an otherwise negative number follows,
    /// in which case a single 0 byte is necessary and even required).
    ///
    /// See https://bitcointalk.org/index.php?topic=8392.msg127623#msg127623
    ///
    /// This function is consensus-critical since BIP66.
    ///
    public var isEncodingValid: Bool {
        // Format: 0x30 [total-length] 0x02 [R-length] [R] 0x02 [S-length] [S]
        // * total-length: 1-byte length descriptor of everything that follows.
        // * R-length: 1-byte length descriptor of the R value that follows.
        // * R: arbitrary-length big-endian encoded R value. It must use the shortest
        //   possible encoding for a positive integer (which means no null bytes at
        //   the start, except a single one when the next byte has its highest bit set).
        // * S-length: 1-byte length descriptor of the S value that follows.
        // * S: arbitrary-length big-endian encoded S value. The same rules apply.
        precondition(type == .ecdsa)

        // Minimum and maximum size constraints.
        guard data.count >= AnySig.ecdsaSignatureMinLength &&
                data.count <= AnySig.ecdsaSignatureMaxLength else {
            return false
        }

        let start = data.startIndex

        // A signature is of type 0x30 (compound).
        if data[start] != 0x30 { return false }

        // Make sure the length covers the entire signature.
        if data[start + 1] != data.count - 2 { return false }

        // Extract the length of the R element.
        let lenR = Int(data[start + 3])

        // Make sure the length of the S element is still inside the signature.
        if 4 + lenR >= data.count { return false }

        // Extract the length of the S element.
        let lenS = Int(data[start + 5 + lenR])

        // Verify that the length of the signature matches the sum of the length
        // of the elements.
        if lenR + lenS + 6 != data.count { return false }

        // Check whether the R element is an integer.
        if data[start + 2] != 0x02 { return false }

        // Zero-length integers are not allowed for R.
        if lenR == 0 { return false }

        // Negative numbers are not allowed for R.
        if data[start + 4] & 0x80 != 0 { return false }

        // Null bytes at the start of R are not allowed, unless R would
        // otherwise be interpreted as a negative number.
        if lenR > 1 && data[start + 4] == 0x00 && data[start + 5] & 0x80 == 0 { return false }

        // Check whether the S element is an integer.
        if data[start + lenR + 4] != 0x02 { return false }

        // Zero-length integers are not allowed for S.
        if lenS == 0 { return false }

        // Negative numbers are not allowed for S.
        if data[start + lenR + 6] & 0x80 != 0 { return false }

        // Null bytes at the start of S are not allowed, unless S would otherwise be
        // interpreted as a negative number.
        if lenS > 1 && data[start + lenR + 6] == 0x00 && data[start + lenR + 7] & 0x80 == 0 { return false }
        return true
    }


    /// Actually hash256
    static let hashLength = 32

    /// Non-canonical ECDSA signature serializations can grow up to 72 bytes without the sighash type 1-byte extension.
    public static let ecdsaSignatureMaxLength = 72
    public static let ecdsaSignatureMinLength = 8

    /// Standard Schnorr signature extended with the sighash type byte.
    public static let schnorrSignatureLength = 64

    /// ECDSA Compact Signature (with non-recoverable public key)
    public static let compactSignatureLength = 64

    /// ECDSA Compact Signature with recoverable public key
    public static let recoverableSignatureLength = 65
}

// MARK: - Some helper functions

private func getMessageHash(messageData: Data, type: SigType) -> Data {
    let newMessageData: Data
    switch type {
    case .ecdsa, .compact, .schnorr:
        newMessageData = messageData
    case .recoverable:
        newMessageData = compactRecoverableMessage(messageData)
    }
    return Data(Hash256.hash(data: newMessageData))
}

// MARK: - ECDSA Compact with Recoverable Public Key

/// Text used to signify that a signed message follows and to prevent inadvertently signing a transaction.
///
/// Used by `compactRecoverableMessage()`.
private let messageMagic = "\u{18}Bitcoin Signed Message:\n"

/// Used for original Bitcoin message signing protocol.
private func compactRecoverableMessage(_ messageData: Data) -> Data {
    messageMagic.data(using: .utf8)! + VarInt(messageData.count).binaryData + messageData
}

/// Produces an ECDSA signature that is compact and from which a public key can be recovered.
///
/// Requires global signing context to be initialized.
private func signRecoverable(hash: Data, secretKey: SecretKey, compressedPubkeys: Bool) -> Data {
    // let hash = [UInt8](compactRecoverableMessageHash(message))
    let hashBytes = [UInt8](hash)
    let secretKeyBytes = [UInt8](secretKey.data)

    var rsig = secp256k1_ecdsa_recoverable_signature()
    guard secp256k1_ecdsa_sign_recoverable(eccSigningContext, &rsig, hashBytes, secretKeyBytes, secp256k1_nonce_function_rfc6979, nil) != 0 else {
        preconditionFailure()
    }

    var sigBytes = [UInt8](repeating: 0, count: AnySig.recoverableSignatureLength)
    var rec: Int32 = -1
    guard secp256k1_ecdsa_recoverable_signature_serialize_compact(eccSigningContext, &sigBytes[1], &rec, &rsig) != 0 else {
        preconditionFailure()
    }

    precondition(rec >= 0 && rec < UInt8.max - 27 - (compressedPubkeys ? 4 : 0))
    sigBytes[0] = UInt8(27 + rec + (compressedPubkeys ? 4 : 0))

    // Additional verification step to prevent using a potentially corrupted signature

    var pubkey = secp256k1_pubkey()
    guard secp256k1_ec_pubkey_create(eccSigningContext, &pubkey, secretKeyBytes) != 0 else {
        preconditionFailure()
    }

    var recoveredPubkey = secp256k1_pubkey()
    guard secp256k1_ecdsa_recover(secp256k1_context_static, &recoveredPubkey, &rsig, hashBytes) != 0 else {
        preconditionFailure()
    }

    guard secp256k1_ec_pubkey_cmp(secp256k1_context_static, &pubkey, &recoveredPubkey) == 0 else {
        preconditionFailure()
    }
    return Data(sigBytes)
}

/// Recovers public key from signature which also verifies the signature as valid.
private func internalRecoverPubkey(sigData: Data, hash: Data) -> Data? {
    precondition(sigData.count == AnySig.recoverableSignatureLength) // throw?

    // TODO: Make it so that we respect the data index.
    assert(sigData.startIndex == 0)

    let hashBytes = [UInt8](hash)

    let recid = Int32((sigData[0] - 27) & 3)
    let comp = ((sigData[0] - 27) & 4) != 0

    let sigSansPrefix = [UInt8](sigData.dropFirst())
    var sig = secp256k1_ecdsa_recoverable_signature()
    guard secp256k1_ecdsa_recoverable_signature_parse_compact(secp256k1_context_static, &sig, sigSansPrefix, recid) != 0 else {
        preconditionFailure() // throw?
    }

    var pubkey = secp256k1_pubkey()
    guard secp256k1_ecdsa_recover(secp256k1_context_static, &pubkey, &sig, hashBytes) != 0 else {
        return .none
    }

    var publen = comp ? PubKey.compressedLength : PubKey.uncompressedLength
    var pub = [UInt8](repeating: 0, count: publen)
    guard secp256k1_ec_pubkey_serialize(secp256k1_context_static, &pub, &publen, &pubkey, UInt32(comp ? SECP256K1_EC_COMPRESSED : SECP256K1_EC_UNCOMPRESSED)) != 0 else {
        preconditionFailure()
    }
    return Data(pub)
}

// MARK: - ECDSA Compact

/// Creates an ECDSA signature with low R value and returns its 64-byte compact (public key non-recoverable) serialization.
///
/// The generated signature will be verified before this function can return.
///
/// Note: This function requires global signing context to be initialized.
///
/// - Parameters:
///   - hash: 32-byte message hash data.
///   - secretKey: 32-byte secret key data.
/// - Returns: 64-byte compact signature data.
///
private func signCompact(hash: Data, secretKey: SecretKey) -> Data {
    let hash = [UInt8](hash)
    let secretKeyBytes = [UInt8](secretKey.data)

    precondition(hash.count == AnySig.hashLength)
    precondition(secretKeyBytes.count == SecretKey.keyLength)

    let testCase = UInt32(0)
    var extraEntropy = [UInt8](repeating: 0, count: 32)
    writeLE32(&extraEntropy, testCase)
    var sig = secp256k1_ecdsa_signature()
    var counter = UInt32(0)
    var success = secp256k1_ecdsa_sign(eccSigningContext, &sig, hash, secretKeyBytes, secp256k1_nonce_function_rfc6979, testCase != 0 ? extraEntropy : nil) != 0
    // Grind for low R
    while success && !isLowR(sig: &sig) {
        counter += 1
        writeLE32(&extraEntropy, counter)
        success = secp256k1_ecdsa_sign(eccSigningContext,  &sig, hash, secretKeyBytes, secp256k1_nonce_function_rfc6979, extraEntropy) != 0
    }
    precondition(success)

    // Additional verification step to prevent using a potentially corrupted signature
    var pubkey = secp256k1_pubkey()
    guard secp256k1_ec_pubkey_create(eccSigningContext, &pubkey, secretKeyBytes) != 0 else {
        preconditionFailure()
    }
    guard secp256k1_ecdsa_verify(secp256k1_context_static, &sig, hash, &pubkey) != 0 else {
        preconditionFailure()
    }

    var sigBytes = [UInt8](repeating: 0, count: AnySig.compactSignatureLength)
    guard secp256k1_ecdsa_signature_serialize_compact(secp256k1_context_static, &sigBytes, &sig) != 0 else {
        preconditionFailure()
    }

    precondition(sigBytes.count == AnySig.compactSignatureLength)
    return Data(sigBytes)
}

private func verifyCompact(sigData: Data, hash: Data, pubkey: PubKey) -> Bool {
    let sigBytes = [UInt8](sigData)
    let hash = [UInt8](hash)
    let pubkeyBytes = [UInt8](pubkey.data)

    precondition(sigData.count == AnySig.compactSignatureLength)
    precondition(hash.count == AnySig.hashLength)

    var sig = secp256k1_ecdsa_signature()
    guard secp256k1_ecdsa_signature_parse_compact(secp256k1_context_static, &sig, sigBytes) != 0 else {
        preconditionFailure()
    }

    var pubkey = secp256k1_pubkey()
    guard secp256k1_ec_pubkey_parse(secp256k1_context_static, &pubkey, pubkeyBytes, pubkeyBytes.count) != 0 else {
        preconditionFailure()
    }

    return secp256k1_ecdsa_verify(secp256k1_context_static, &sig, hash, &pubkey) != 0
}

// MARK: - Schnorr

/// Requires global signing context to be initialized.
private func signSchnorr(hash: Data, secretKey: SecretKey, additionalEntropy: Data?) -> Data {
    precondition(hash.count == AnySig.hashLength)

    let hashBytes = [UInt8](hash)
    let secretKeyBytes = [UInt8](secretKey.data)
    let auxBytes = if let additionalEntropy { [UInt8](additionalEntropy) } else { [UInt8]?.none }

    var keypair = secp256k1_keypair()
    guard secp256k1_keypair_create(eccSigningContext, &keypair, secretKeyBytes) != 0 else {
        preconditionFailure()
    }

    // Do the signing.
    var sigOut = [UInt8](repeating: 0, count: 64)
    guard secp256k1_schnorrsig_sign32(eccSigningContext, &sigOut, hashBytes, &keypair, auxBytes) != 0 else {
        preconditionFailure()
    }

    // Additional verification step to prevent using a potentially corrupted signature.
    // This public key will be tweaked if a tweak was added to the keypair earlier.
    var xonlyPubkey = secp256k1_xonly_pubkey()
    guard secp256k1_keypair_xonly_pub(secp256k1_context_static, &xonlyPubkey, nil, &keypair) != 0 else {
        preconditionFailure()
    }

    guard secp256k1_schnorrsig_verify(secp256k1_context_static, sigOut, hashBytes, AnySig.hashLength, &xonlyPubkey) != 0 else {
        preconditionFailure()
    }

    return Data(sigOut)
}

private func verifySchnorr(sigData: Data, hash: Data, pubkey: PubKey) -> Bool {

    precondition(sigData.count == AnySig.schnorrSignatureLength)
    precondition(hash.count == AnySig.hashLength)
    // guard !pubkeyData.isEmpty else { return false }

    let sigBytes = [UInt8](sigData)
    let pubkeyBytes = [UInt8](pubkey.xOnlyData)
    let hashBytes = [UInt8](hash)

    var xonlyPubkey = secp256k1_xonly_pubkey()
    guard secp256k1_xonly_pubkey_parse(secp256k1_context_static, &xonlyPubkey, pubkeyBytes) != 0 else {
        return false
    }
    return secp256k1_schnorrsig_verify(secp256k1_context_static, sigBytes, hashBytes, hashBytes.count, &xonlyPubkey) != 0
}

// MARK: - ECDSA

/// Requires global signing context to be initialized.
private func signECDSA(hash: Data, secretKey: SecretKey, requireLowR: Bool = true) -> Data {

    precondition(hash.count == AnySig.hashLength)

    let hashBytes = [UInt8](hash)
    let secretKeyBytes = [UInt8](secretKey.data)

    let testCase = UInt32(0)
    var extraEntropy = [UInt8](repeating: 0, count: 32)
    writeLE32(&extraEntropy, testCase)
    var sig = secp256k1_ecdsa_signature()
    var counter = UInt32(0)
    var success = secp256k1_ecdsa_sign(eccSigningContext, &sig, hashBytes, secretKeyBytes, secp256k1_nonce_function_rfc6979, (requireLowR && testCase != 0) ? extraEntropy : nil) != 0
    // Grind for low R
    while (success && !isLowR(sig: &sig) && requireLowR) {
        counter += 1
        writeLE32(&extraEntropy, counter)
        success = secp256k1_ecdsa_sign(eccSigningContext,  &sig, hashBytes, secretKeyBytes, secp256k1_nonce_function_rfc6979, extraEntropy) != 0
    }
    precondition(success)

    var sigBytes = [UInt8](repeating: 0, count: AnySig.ecdsaSignatureMaxLength)
    var sigBytesCount = sigBytes.count
    guard secp256k1_ecdsa_signature_serialize_der(secp256k1_context_static, &sigBytes, &sigBytesCount, &sig) != 0 else {
        preconditionFailure()
    }

    // Resize (shrink) if necessary
    let sigShrunken = Data(sigBytes[sigBytes.startIndex ..< sigBytes.startIndex.advanced(by: sigBytesCount)])

    // Additional verification step to prevent using a potentially corrupted signature
    var pubkey = secp256k1_pubkey()
    guard secp256k1_ec_pubkey_create(eccSigningContext, &pubkey, secretKeyBytes) != 0 else {
        preconditionFailure()
    }

    guard secp256k1_ecdsa_verify(secp256k1_context_static, &sig, hashBytes, &pubkey) != 0 else {
        preconditionFailure()
    }

    return sigShrunken
}

/// Verifies a signature using a public key.
private func verifyECDSA(sigData: Data, hash: Data, pubkey: PubKey) -> Bool {

    // TODO: Verify the assumption below
    // guard !pubkey.data.isEmpty else { return false }

    let sigBytes = [UInt8](sigData)
    let pubkeyBytes = [UInt8](pubkey.data)
    let hashBytes = [UInt8](hash)

    var sig = secp256k1_ecdsa_signature()
    guard ECCHelper.ecdsa_signature_parse_der_lax(&sig, sigBytes, sigBytes.count) != 0 else {
        preconditionFailure()
    }

    var sigNormalized = secp256k1_ecdsa_signature()
    secp256k1_ecdsa_signature_normalize(secp256k1_context_static, &sigNormalized, &sig)

    var pubkey = secp256k1_pubkey()
    guard secp256k1_ec_pubkey_parse(secp256k1_context_static, &pubkey, pubkeyBytes, pubkeyBytes.count) != 0 else {
        preconditionFailure()
    }

    return secp256k1_ecdsa_verify(secp256k1_context_static, &sigNormalized, hashBytes, &pubkey) != 0
}

// Check that the sig has a low R value and will be less than 71 bytes
private func isLowR(sig: inout secp256k1_ecdsa_signature) -> Bool {
    var compactSig = [UInt8](repeating: 0, count: 64)
    secp256k1_ecdsa_signature_serialize_compact(secp256k1_context_static, &compactSig, &sig);

    // In DER serialization, all values are interpreted as big-endian, signed integers. The highest bit in the integer indicates
    // its signed-ness; 0 is positive, 1 is negative. When the value is interpreted as a negative integer, it must be converted
    // to a positive value by prepending a 0x00 byte so that the highest bit is 0. We can avoid this prepending by ensuring that
    // our highest bit is always 0, and thus we must check that the first byte is less than 0x80.
    return compactSig[0] < 0x80
}

private func internalIsLowS(compactSignatureData: Data) -> Bool {
    let sigBytes = [UInt8](compactSignatureData)
    var sig = secp256k1_ecdsa_signature()
    guard secp256k1_ecdsa_signature_parse_compact(secp256k1_context_static, &sig, sigBytes) != 0 else {
        preconditionFailure()
    }
    let normalizationOccurred = secp256k1_ecdsa_signature_normalize(secp256k1_context_static, .none, &sig)
    return normalizationOccurred == 0
}

private func internalIsLowS(laxSignatureData: Data) -> Bool {
    let sigBytes = [UInt8](laxSignatureData)
    var sig = secp256k1_ecdsa_signature()
    guard ecdsa_signature_parse_der_lax(&sig, sigBytes, sigBytes.count) != 0 else {
        preconditionFailure()
    }
    let normalizationOccurred = secp256k1_ecdsa_signature_normalize(secp256k1_context_static, .none, &sig)
    return normalizationOccurred == 0
}
