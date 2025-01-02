import Testing
import Foundation
import BitcoinCrypto
@testable import BitcoinBase

struct BIP340Tests {

    @Test("Sign Schnorr", arguments: [
            ([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03] as [UInt8], [0xf9, 0x30, 0x8a, 0x01, 0x92, 0x58, 0xc3, 0x10, 0x49, 0x34, 0x4f, 0x85, 0xf8, 0x9d, 0x52, 0x29, 0xb5, 0x31, 0xc8, 0x45, 0x83, 0x6f, 0x99, 0xb0, 0x86, 0x01, 0xf1, 0x13, 0xbc, 0xe0, 0x36, 0xf9] as [UInt8], [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00] as [UInt8], [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00] as [UInt8], [0xe9, 0x07, 0x83, 0x1f, 0x80, 0x84, 0x8d, 0x10, 0x69, 0xa5, 0x37, 0x1b, 0x40, 0x24, 0x10, 0x36, 0x4b, 0xdf, 0x1c, 0x5f, 0x83, 0x07, 0xb0, 0x08, 0x4c, 0x55, 0xf1, 0xce, 0x2d, 0xca, 0x82, 0x15, 0x25, 0xf6, 0x6a, 0x4a, 0x85, 0xea, 0x8b, 0x71, 0xe4, 0x82, 0xa7, 0x4f, 0x38, 0x2d, 0x2c, 0xe5, 0xeb, 0xee, 0xe8, 0xfd, 0xb2, 0x17, 0x2f, 0x47, 0x7d, 0xf4, 0x90, 0x0d, 0x31, 0x05, 0x36, 0xc0] as [UInt8]),
            ([0xb7, 0xe1, 0x51, 0x62, 0x8a, 0xed, 0x2a, 0x6a, 0xbf, 0x71, 0x58, 0x80, 0x9c, 0xf4, 0xf3, 0xc7, 0x62, 0xe7, 0x16, 0x0f, 0x38, 0xb4, 0xda, 0x56, 0xa7, 0x84, 0xd9, 0x04, 0x51, 0x90, 0xcf, 0xef], [0xdf, 0xf1, 0xd7, 0x7f, 0x2a, 0x67, 0x1c, 0x5f, 0x36, 0x18, 0x37, 0x26, 0xdb, 0x23, 0x41, 0xbe, 0x58, 0xfe, 0xae, 0x1d, 0xa2, 0xde, 0xce, 0xd8, 0x43, 0x24, 0x0f, 0x7b, 0x50, 0x2b, 0xa6, 0x59], [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01], [0x24, 0x3f, 0x6a, 0x88, 0x85, 0xa3, 0x08, 0xd3, 0x13, 0x19, 0x8a, 0x2e, 0x03, 0x70, 0x73, 0x44, 0xa4, 0x09, 0x38, 0x22, 0x29, 0x9f, 0x31, 0xd0, 0x08, 0x2e, 0xfa, 0x98, 0xec, 0x4e, 0x6c, 0x89], [0x68, 0x96, 0xbd, 0x60, 0xee, 0xae, 0x29, 0x6d, 0xb4, 0x8a, 0x22, 0x9f, 0xf7, 0x1d, 0xfe, 0x07, 0x1b, 0xde, 0x41, 0x3e, 0x6d, 0x43, 0xf9, 0x17, 0xdc, 0x8d, 0xcf, 0x8c, 0x78, 0xde, 0x33, 0x41, 0x89, 0x06, 0xd1, 0x1a, 0xc9, 0x76, 0xab, 0xcc, 0xb2, 0x0b, 0x09, 0x12, 0x92, 0xbf, 0xf4, 0xea, 0x89, 0x7e, 0xfc, 0xb6, 0x39, 0xea, 0x87, 0x1c, 0xfa, 0x95, 0xf6, 0xde, 0x33, 0x9e, 0x4b, 0x0a]),
            ([0xc9, 0x0f, 0xda, 0xa2, 0x21, 0x68, 0xc2, 0x34, 0xc4, 0xc6, 0x62, 0x8b, 0x80, 0xdc, 0x1c, 0xd1, 0x29, 0x02, 0x4e, 0x08, 0x8a, 0x67, 0xcc, 0x74, 0x02, 0x0b, 0xbe, 0xa6, 0x3b, 0x14, 0xe5, 0xc9], [0xdd, 0x30, 0x8a, 0xfe, 0xc5, 0x77, 0x7e, 0x13, 0x12, 0x1f, 0xa7, 0x2b, 0x9c, 0xc1, 0xb7, 0xcc, 0x01, 0x39, 0x71, 0x53, 0x09, 0xb0, 0x86, 0xc9, 0x60, 0xe1, 0x8f, 0xd9, 0x69, 0x77, 0x4e, 0xb8], [0xc8, 0x7a, 0xa5, 0x38, 0x24, 0xb4, 0xd7, 0xae, 0x2e, 0xb0, 0x35, 0xa2, 0xb5, 0xbb, 0xbc, 0xcc, 0x08, 0x0e, 0x76, 0xcd, 0xc6, 0xd1, 0x69, 0x2c, 0x4b, 0x0b, 0x62, 0xd7, 0x98, 0xe6, 0xd9, 0x06], [0x7e, 0x2d, 0x58, 0xd8, 0xb3, 0xbc, 0xdf, 0x1a, 0xba, 0xde, 0xc7, 0x82, 0x90, 0x54, 0xf9, 0x0d, 0xda, 0x98, 0x05, 0xaa, 0xb5, 0x6c, 0x77, 0x33, 0x30, 0x24, 0xb9, 0xd0, 0xa5, 0x08, 0xb7, 0x5c], [0x58, 0x31, 0xaa, 0xee, 0xd7, 0xb4, 0x4b, 0xb7, 0x4e, 0x5e, 0xab, 0x94, 0xba, 0x9d, 0x42, 0x94, 0xc4, 0x9b, 0xcf, 0x2a, 0x60, 0x72, 0x8d, 0x8b, 0x4c, 0x20, 0x0f, 0x50, 0xdd, 0x31, 0x3c, 0x1b, 0xab, 0x74, 0x58, 0x79, 0xa5, 0xad, 0x95, 0x4a, 0x72, 0xc4, 0x5a, 0x91, 0xc3, 0xa5, 0x1d, 0x3c, 0x7a, 0xde, 0xa9, 0x8d, 0x82, 0xf8, 0x48, 0x1e, 0x0e, 0x1e, 0x03, 0x67, 0x4a, 0x6f, 0x3f, 0xb7]),
            ([0x0b, 0x43, 0x2b, 0x26, 0x77, 0x93, 0x73, 0x81, 0xae, 0xf0, 0x5b, 0xb0, 0x2a, 0x66, 0xec, 0xd0, 0x12, 0x77, 0x30, 0x62, 0xcf, 0x3f, 0xa2, 0x54, 0x9e, 0x44, 0xf5, 0x8e, 0xd2, 0x40, 0x17, 0x10], [0x25, 0xd1, 0xdf, 0xf9, 0x51, 0x05, 0xf5, 0x25, 0x3c, 0x40, 0x22, 0xf6, 0x28, 0xa9, 0x96, 0xad, 0x3a, 0x0d, 0x95, 0xfb, 0xf2, 0x1d, 0x46, 0x8a, 0x1b, 0x33, 0xf8, 0xc1, 0x60, 0xd8, 0xf5, 0x17], [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff], [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff], [0x7e, 0xb0, 0x50, 0x97, 0x57, 0xe2, 0x46, 0xf1, 0x94, 0x49, 0x88, 0x56, 0x51, 0x61, 0x1c, 0xb9, 0x65, 0xec, 0xc1, 0xa1, 0x87, 0xdd, 0x51, 0xb6, 0x4f, 0xda, 0x1e, 0xdc, 0x96, 0x37, 0xd5, 0xec, 0x97, 0x58, 0x2b, 0x9c, 0xb1, 0x3d, 0xb3, 0x93, 0x37, 0x05, 0xb3, 0x2b, 0xa9, 0x82, 0xaf, 0x5a, 0xf2, 0x5f, 0xd7, 0x88, 0x81, 0xeb, 0xb3, 0x27, 0x71, 0xfc, 0x59, 0x22, 0xef, 0xc6, 0x6e, 0xa3])
        ])
    func signWithSchnorr(secretKeyBytes: [UInt8], internalKeyBytes: [UInt8], aux: [UInt8], msg: [UInt8], sig: [UInt8]) throws {
        let secretKeyData = Data(secretKeyBytes)
        let internalKeyData = Data(internalKeyBytes)
        let auxData = Data(aux)
        let msgData = Data(msg)
        let sigData = Data(sig)

        let secretKey = try #require(SecretKey(secretKeyData))
        let internalKey = try #require(PublicKey(xOnly: internalKeyData))
        let newSignature = AnySig(hash: msgData, secretKey: secretKey, type: .schnorr, additionalEntropy: auxData)
        #expect(newSignature.data == sigData)
        // Verify those sigs for good measure.
        #expect(newSignature.verify(hash: msgData, publicKey: internalKey))

        // Do 10 iterations where we sign with a random Merkle root to tweak,
        // and compare against the resulting tweaked keys, with random aux.
        // In iteration i=0 we tweak with empty Merkle tree.
        for i in 0 ..< 10 {
            let merkleRoot: Data = i == 0 ? .init() : Data(getRandBytes(32))
            let auxRnd = Data(getRandBytes(32))
            let internalKey = try #require(PublicKey(xOnly: internalKeyData))
            let tweak = internalKey.tapTweak(merkleRoot: merkleRoot)
            let outputKey = internalKey.tweakXOnly(tweak)

            #expect(internalKey.checkTweak(tweak, outputKey: outputKey))

            let tweakedSecretKey = secretKey.tweakXOnly(tweak)
            let altSignature = AnySig(hash: msgData, secretKey: tweakedSecretKey, type: .schnorr, additionalEntropy: auxRnd)
            let verificationResult = altSignature.verify(hash: msgData, publicKey: outputKey)
            #expect(verificationResult)
        }
    }

    @Test("Verify schnorr", arguments: [
        ([0xf9, 0x30, 0x8a, 0x01, 0x92, 0x58, 0xc3, 0x10, 0x49, 0x34, 0x4f, 0x85, 0xf8, 0x9d, 0x52, 0x29, 0xb5, 0x31, 0xc8, 0x45, 0x83, 0x6f, 0x99, 0xb0, 0x86, 0x01, 0xf1, 0x13, 0xbc, 0xe0, 0x36, 0xf9] as [UInt8], [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00] as [UInt8], [0xe9, 0x07, 0x83, 0x1f, 0x80, 0x84, 0x8d, 0x10, 0x69, 0xa5, 0x37, 0x1b, 0x40, 0x24, 0x10, 0x36, 0x4b, 0xdf, 0x1c, 0x5f, 0x83, 0x07, 0xb0, 0x08, 0x4c, 0x55, 0xf1, 0xce, 0x2d, 0xca, 0x82, 0x15, 0x25, 0xf6, 0x6a, 0x4a, 0x85, 0xea, 0x8b, 0x71, 0xe4, 0x82, 0xa7, 0x4f, 0x38, 0x2d, 0x2c, 0xe5, 0xeb, 0xee, 0xe8, 0xfd, 0xb2, 0x17, 0x2f, 0x47, 0x7d, 0xf4, 0x90, 0x0d, 0x31, 0x05, 0x36, 0xc0] as [UInt8], true),
        ([0xdf, 0xf1, 0xd7, 0x7f, 0x2a, 0x67, 0x1c, 0x5f, 0x36, 0x18, 0x37, 0x26, 0xdb, 0x23, 0x41, 0xbe, 0x58, 0xfe, 0xae, 0x1d, 0xa2, 0xde, 0xce, 0xd8, 0x43, 0x24, 0x0f, 0x7b, 0x50, 0x2b, 0xa6, 0x59], [0x24, 0x3f, 0x6a, 0x88, 0x85, 0xa3, 0x08, 0xd3, 0x13, 0x19, 0x8a, 0x2e, 0x03, 0x70, 0x73, 0x44, 0xa4, 0x09, 0x38, 0x22, 0x29, 0x9f, 0x31, 0xd0, 0x08, 0x2e, 0xfa, 0x98, 0xec, 0x4e, 0x6c, 0x89], [0x68, 0x96, 0xbd, 0x60, 0xee, 0xae, 0x29, 0x6d, 0xb4, 0x8a, 0x22, 0x9f, 0xf7, 0x1d, 0xfe, 0x07, 0x1b, 0xde, 0x41, 0x3e, 0x6d, 0x43, 0xf9, 0x17, 0xdc, 0x8d, 0xcf, 0x8c, 0x78, 0xde, 0x33, 0x41, 0x89, 0x06, 0xd1, 0x1a, 0xc9, 0x76, 0xab, 0xcc, 0xb2, 0x0b, 0x09, 0x12, 0x92, 0xbf, 0xf4, 0xea, 0x89, 0x7e, 0xfc, 0xb6, 0x39, 0xea, 0x87, 0x1c, 0xfa, 0x95, 0xf6, 0xde, 0x33, 0x9e, 0x4b, 0x0a], true),
        ([0xdd, 0x30, 0x8a, 0xfe, 0xc5, 0x77, 0x7e, 0x13, 0x12, 0x1f, 0xa7, 0x2b, 0x9c, 0xc1, 0xb7, 0xcc, 0x01, 0x39, 0x71, 0x53, 0x09, 0xb0, 0x86, 0xc9, 0x60, 0xe1, 0x8f, 0xd9, 0x69, 0x77, 0x4e, 0xb8], [0x7e, 0x2d, 0x58, 0xd8, 0xb3, 0xbc, 0xdf, 0x1a, 0xba, 0xde, 0xc7, 0x82, 0x90, 0x54, 0xf9, 0x0d, 0xda, 0x98, 0x05, 0xaa, 0xb5, 0x6c, 0x77, 0x33, 0x30, 0x24, 0xb9, 0xd0, 0xa5, 0x08, 0xb7, 0x5c], [0x58, 0x31, 0xaa, 0xee, 0xd7, 0xb4, 0x4b, 0xb7, 0x4e, 0x5e, 0xab, 0x94, 0xba, 0x9d, 0x42, 0x94, 0xc4, 0x9b, 0xcf, 0x2a, 0x60, 0x72, 0x8d, 0x8b, 0x4c, 0x20, 0x0f, 0x50, 0xdd, 0x31, 0x3c, 0x1b, 0xab, 0x74, 0x58, 0x79, 0xa5, 0xad, 0x95, 0x4a, 0x72, 0xc4, 0x5a, 0x91, 0xc3, 0xa5, 0x1d, 0x3c, 0x7a, 0xde, 0xa9, 0x8d, 0x82, 0xf8, 0x48, 0x1e, 0x0e, 0x1e, 0x03, 0x67, 0x4a, 0x6f, 0x3f, 0xb7], true),
        ([0x25, 0xd1, 0xdf, 0xf9, 0x51, 0x05, 0xf5, 0x25, 0x3c, 0x40, 0x22, 0xf6, 0x28, 0xa9, 0x96, 0xad, 0x3a, 0x0d, 0x95, 0xfb, 0xf2, 0x1d, 0x46, 0x8a, 0x1b, 0x33, 0xf8, 0xc1, 0x60, 0xd8, 0xf5, 0x17], [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff], [0x7e, 0xb0, 0x50, 0x97, 0x57, 0xe2, 0x46, 0xf1, 0x94, 0x49, 0x88, 0x56, 0x51, 0x61, 0x1c, 0xb9, 0x65, 0xec, 0xc1, 0xa1, 0x87, 0xdd, 0x51, 0xb6, 0x4f, 0xda, 0x1e, 0xdc, 0x96, 0x37, 0xd5, 0xec, 0x97, 0x58, 0x2b, 0x9c, 0xb1, 0x3d, 0xb3, 0x93, 0x37, 0x05, 0xb3, 0x2b, 0xa9, 0x82, 0xaf, 0x5a, 0xf2, 0x5f, 0xd7, 0x88, 0x81, 0xeb, 0xb3, 0x27, 0x71, 0xfc, 0x59, 0x22, 0xef, 0xc6, 0x6e, 0xa3], true),
        ([0xd6, 0x9c, 0x35, 0x09, 0xbb, 0x99, 0xe4, 0x12, 0xe6, 0x8b, 0x0f, 0xe8, 0x54, 0x4e, 0x72, 0x83, 0x7d, 0xfa, 0x30, 0x74, 0x6d, 0x8b, 0xe2, 0xaa, 0x65, 0x97, 0x5f, 0x29, 0xd2, 0x2d, 0xc7, 0xb9], [0x4d, 0xf3, 0xc3, 0xf6, 0x8f, 0xcc, 0x83, 0xb2, 0x7e, 0x9d, 0x42, 0xc9, 0x04, 0x31, 0xa7, 0x24, 0x99, 0xf1, 0x78, 0x75, 0xc8, 0x1a, 0x59, 0x9b, 0x56, 0x6c, 0x98, 0x89, 0xb9, 0x69, 0x67, 0x03], [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3b, 0x78, 0xce, 0x56, 0x3f, 0x89, 0xa0, 0xed, 0x94, 0x14, 0xf5, 0xaa, 0x28, 0xad, 0x0d, 0x96, 0xd6, 0x79, 0x5f, 0x9c, 0x63, 0x76, 0xaf, 0xb1, 0x54, 0x8a, 0xf6, 0x03, 0xb3, 0xeb, 0x45, 0xc9, 0xf8, 0x20, 0x7d, 0xee, 0x10, 0x60, 0xcb, 0x71, 0xc0, 0x4e, 0x80, 0xf5, 0x93, 0x06, 0x0b, 0x07, 0xd2, 0x83, 0x08, 0xd7, 0xf4], true),
        ([0xee, 0xfd, 0xea, 0x4c, 0xdb, 0x67, 0x77, 0x50, 0xa4, 0x20, 0xfe, 0xe8, 0x07, 0xea, 0xcf, 0x21, 0xeb, 0x98, 0x98, 0xae, 0x79, 0xb9, 0x76, 0x87, 0x66, 0xe4, 0xfa, 0xa0, 0x4a, 0x2d, 0x4a, 0x34], [0x24, 0x3f, 0x6a, 0x88, 0x85, 0xa3, 0x08, 0xd3, 0x13, 0x19, 0x8a, 0x2e, 0x03, 0x70, 0x73, 0x44, 0xa4, 0x09, 0x38, 0x22, 0x29, 0x9f, 0x31, 0xd0, 0x08, 0x2e, 0xfa, 0x98, 0xec, 0x4e, 0x6c, 0x89], [0x6c, 0xff, 0x5c, 0x3b, 0xa8, 0x6c, 0x69, 0xea, 0x4b, 0x73, 0x76, 0xf3, 0x1a, 0x9b, 0xcb, 0x4f, 0x74, 0xc1, 0x97, 0x60, 0x89, 0xb2, 0xd9, 0x96, 0x3d, 0xa2, 0xe5, 0x54, 0x3e, 0x17, 0x77, 0x69, 0x69, 0xe8, 0x9b, 0x4c, 0x55, 0x64, 0xd0, 0x03, 0x49, 0x10, 0x6b, 0x84, 0x97, 0x78, 0x5d, 0xd7, 0xd1, 0xd7, 0x13, 0xa8, 0xae, 0x82, 0xb3, 0x2f, 0xa7, 0x9d, 0x5f, 0x7f, 0xc4, 0x07, 0xd3, 0x9b], false),
        ([0xdf, 0xf1, 0xd7, 0x7f, 0x2a, 0x67, 0x1c, 0x5f, 0x36, 0x18, 0x37, 0x26, 0xdb, 0x23, 0x41, 0xbe, 0x58, 0xfe, 0xae, 0x1d, 0xa2, 0xde, 0xce, 0xd8, 0x43, 0x24, 0x0f, 0x7b, 0x50, 0x2b, 0xa6, 0x59], [0x24, 0x3f, 0x6a, 0x88, 0x85, 0xa3, 0x08, 0xd3, 0x13, 0x19, 0x8a, 0x2e, 0x03, 0x70, 0x73, 0x44, 0xa4, 0x09, 0x38, 0x22, 0x29, 0x9f, 0x31, 0xd0, 0x08, 0x2e, 0xfa, 0x98, 0xec, 0x4e, 0x6c, 0x89], [0xff, 0xf9, 0x7b, 0xd5, 0x75, 0x5e, 0xee, 0xa4, 0x20, 0x45, 0x3a, 0x14, 0x35, 0x52, 0x35, 0xd3, 0x82, 0xf6, 0x47, 0x2f, 0x85, 0x68, 0xa1, 0x8b, 0x2f, 0x05, 0x7a, 0x14, 0x60, 0x29, 0x75, 0x56, 0x3c, 0xc2, 0x79, 0x44, 0x64, 0x0a, 0xc6, 0x07, 0xcd, 0x10, 0x7a, 0xe1, 0x09, 0x23, 0xd9, 0xef, 0x7a, 0x73, 0xc6, 0x43, 0xe1, 0x66, 0xbe, 0x5e, 0xbe, 0xaf, 0xa3, 0x4b, 0x1a, 0xc5, 0x53, 0xe2], false),
        ([0xdf, 0xf1, 0xd7, 0x7f, 0x2a, 0x67, 0x1c, 0x5f, 0x36, 0x18, 0x37, 0x26, 0xdb, 0x23, 0x41, 0xbe, 0x58, 0xfe, 0xae, 0x1d, 0xa2, 0xde, 0xce, 0xd8, 0x43, 0x24, 0x0f, 0x7b, 0x50, 0x2b, 0xa6, 0x59], [0x24, 0x3f, 0x6a, 0x88, 0x85, 0xa3, 0x08, 0xd3, 0x13, 0x19, 0x8a, 0x2e, 0x03, 0x70, 0x73, 0x44, 0xa4, 0x09, 0x38, 0x22, 0x29, 0x9f, 0x31, 0xd0, 0x08, 0x2e, 0xfa, 0x98, 0xec, 0x4e, 0x6c, 0x89], [0x1f, 0xa6, 0x2e, 0x33, 0x1e, 0xdb, 0xc2, 0x1c, 0x39, 0x47, 0x92, 0xd2, 0xab, 0x11, 0x00, 0xa7, 0xb4, 0x32, 0xb0, 0x13, 0xdf, 0x3f, 0x6f, 0xf4, 0xf9, 0x9f, 0xcb, 0x33, 0xe0, 0xe1, 0x51, 0x5f, 0x28, 0x89, 0x0b, 0x3e, 0xdb, 0x6e, 0x71, 0x89, 0xb6, 0x30, 0x44, 0x8b, 0x51, 0x5c, 0xe4, 0xf8, 0x62, 0x2a, 0x95, 0x4c, 0xfe, 0x54, 0x57, 0x35, 0xaa, 0xea, 0x51, 0x34, 0xfc, 0xcd, 0xb2, 0xbd], false),
        ([0xdf, 0xf1, 0xd7, 0x7f, 0x2a, 0x67, 0x1c, 0x5f, 0x36, 0x18, 0x37, 0x26, 0xdb, 0x23, 0x41, 0xbe, 0x58, 0xfe, 0xae, 0x1d, 0xa2, 0xde, 0xce, 0xd8, 0x43, 0x24, 0x0f, 0x7b, 0x50, 0x2b, 0xa6, 0x59], [0x24, 0x3f, 0x6a, 0x88, 0x85, 0xa3, 0x08, 0xd3, 0x13, 0x19, 0x8a, 0x2e, 0x03, 0x70, 0x73, 0x44, 0xa4, 0x09, 0x38, 0x22, 0x29, 0x9f, 0x31, 0xd0, 0x08, 0x2e, 0xfa, 0x98, 0xec, 0x4e, 0x6c, 0x89], [0x6c, 0xff, 0x5c, 0x3b, 0xa8, 0x6c, 0x69, 0xea, 0x4b, 0x73, 0x76, 0xf3, 0x1a, 0x9b, 0xcb, 0x4f, 0x74, 0xc1, 0x97, 0x60, 0x89, 0xb2, 0xd9, 0x96, 0x3d, 0xa2, 0xe5, 0x54, 0x3e, 0x17, 0x77, 0x69, 0x96, 0x17, 0x64, 0xb3, 0xaa, 0x9b, 0x2f, 0xfc, 0xb6, 0xef, 0x94, 0x7b, 0x68, 0x87, 0xa2, 0x26, 0xe8, 0xd7, 0xc9, 0x3e, 0x00, 0xc5, 0xed, 0x0c, 0x18, 0x34, 0xff, 0x0d, 0x0c, 0x2e, 0x6d, 0xa6], false),
        ([0xdf, 0xf1, 0xd7, 0x7f, 0x2a, 0x67, 0x1c, 0x5f, 0x36, 0x18, 0x37, 0x26, 0xdb, 0x23, 0x41, 0xbe, 0x58, 0xfe, 0xae, 0x1d, 0xa2, 0xde, 0xce, 0xd8, 0x43, 0x24, 0x0f, 0x7b, 0x50, 0x2b, 0xa6, 0x59], [0x24, 0x3f, 0x6a, 0x88, 0x85, 0xa3, 0x08, 0xd3, 0x13, 0x19, 0x8a, 0x2e, 0x03, 0x70, 0x73, 0x44, 0xa4, 0x09, 0x38, 0x22, 0x29, 0x9f, 0x31, 0xd0, 0x08, 0x2e, 0xfa, 0x98, 0xec, 0x4e, 0x6c, 0x89], [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x12, 0x3d, 0xda, 0x83, 0x28, 0xaf, 0x9c, 0x23, 0xa9, 0x4c, 0x1f, 0xee, 0xcf, 0xd1, 0x23, 0xba, 0x4f, 0xb7, 0x34, 0x76, 0xf0, 0xd5, 0x94, 0xdc, 0xb6, 0x5c, 0x64, 0x25, 0xbd, 0x18, 0x60, 0x51], false),
        ([0xdf, 0xf1, 0xd7, 0x7f, 0x2a, 0x67, 0x1c, 0x5f, 0x36, 0x18, 0x37, 0x26, 0xdb, 0x23, 0x41, 0xbe, 0x58, 0xfe, 0xae, 0x1d, 0xa2, 0xde, 0xce, 0xd8, 0x43, 0x24, 0x0f, 0x7b, 0x50, 0x2b, 0xa6, 0x59], [0x24, 0x3f, 0x6a, 0x88, 0x85, 0xa3, 0x08, 0xd3, 0x13, 0x19, 0x8a, 0x2e, 0x03, 0x70, 0x73, 0x44, 0xa4, 0x09, 0x38, 0x22, 0x29, 0x9f, 0x31, 0xd0, 0x08, 0x2e, 0xfa, 0x98, 0xec, 0x4e, 0x6c, 0x89], [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x76, 0x15, 0xfb, 0xaf, 0x5a, 0xe2, 0x88, 0x64, 0x01, 0x3c, 0x09, 0x97, 0x42, 0xde, 0xad, 0xb4, 0xdb, 0xa8, 0x7f, 0x11, 0xac, 0x67, 0x54, 0xf9, 0x37, 0x80, 0xd5, 0xa1, 0x83, 0x7c, 0xf1, 0x97], false),
        ([0xdf, 0xf1, 0xd7, 0x7f, 0x2a, 0x67, 0x1c, 0x5f, 0x36, 0x18, 0x37, 0x26, 0xdb, 0x23, 0x41, 0xbe, 0x58, 0xfe, 0xae, 0x1d, 0xa2, 0xde, 0xce, 0xd8, 0x43, 0x24, 0x0f, 0x7b, 0x50, 0x2b, 0xa6, 0x59], [0x24, 0x3f, 0x6a, 0x88, 0x85, 0xa3, 0x08, 0xd3, 0x13, 0x19, 0x8a, 0x2e, 0x03, 0x70, 0x73, 0x44, 0xa4, 0x09, 0x38, 0x22, 0x29, 0x9f, 0x31, 0xd0, 0x08, 0x2e, 0xfa, 0x98, 0xec, 0x4e, 0x6c, 0x89], [0x4a, 0x29, 0x8d, 0xac, 0xae, 0x57, 0x39, 0x5a, 0x15, 0xd0, 0x79, 0x5d, 0xdb, 0xfd, 0x1d, 0xcb, 0x56, 0x4d, 0xa8, 0x2b, 0x0f, 0x26, 0x9b, 0xc7, 0x0a, 0x74, 0xf8, 0x22, 0x04, 0x29, 0xba, 0x1d, 0x69, 0xe8, 0x9b, 0x4c, 0x55, 0x64, 0xd0, 0x03, 0x49, 0x10, 0x6b, 0x84, 0x97, 0x78, 0x5d, 0xd7, 0xd1, 0xd7, 0x13, 0xa8, 0xae, 0x82, 0xb3, 0x2f, 0xa7, 0x9d, 0x5f, 0x7f, 0xc4, 0x07, 0xd3, 0x9b], false),
        ([0xdf, 0xf1, 0xd7, 0x7f, 0x2a, 0x67, 0x1c, 0x5f, 0x36, 0x18, 0x37, 0x26, 0xdb, 0x23, 0x41, 0xbe, 0x58, 0xfe, 0xae, 0x1d, 0xa2, 0xde, 0xce, 0xd8, 0x43, 0x24, 0x0f, 0x7b, 0x50, 0x2b, 0xa6, 0x59], [0x24, 0x3f, 0x6a, 0x88, 0x85, 0xa3, 0x08, 0xd3, 0x13, 0x19, 0x8a, 0x2e, 0x03, 0x70, 0x73, 0x44, 0xa4, 0x09, 0x38, 0x22, 0x29, 0x9f, 0x31, 0xd0, 0x08, 0x2e, 0xfa, 0x98, 0xec, 0x4e, 0x6c, 0x89], [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xfe, 0xff, 0xff, 0xfc, 0x2f, 0x69, 0xe8, 0x9b, 0x4c, 0x55, 0x64, 0xd0, 0x03, 0x49, 0x10, 0x6b, 0x84, 0x97, 0x78, 0x5d, 0xd7, 0xd1, 0xd7, 0x13, 0xa8, 0xae, 0x82, 0xb3, 0x2f, 0xa7, 0x9d, 0x5f, 0x7f, 0xc4, 0x07, 0xd3, 0x9b], false),
        ([0xdf, 0xf1, 0xd7, 0x7f, 0x2a, 0x67, 0x1c, 0x5f, 0x36, 0x18, 0x37, 0x26, 0xdb, 0x23, 0x41, 0xbe, 0x58, 0xfe, 0xae, 0x1d, 0xa2, 0xde, 0xce, 0xd8, 0x43, 0x24, 0x0f, 0x7b, 0x50, 0x2b, 0xa6, 0x59], [0x24, 0x3f, 0x6a, 0x88, 0x85, 0xa3, 0x08, 0xd3, 0x13, 0x19, 0x8a, 0x2e, 0x03, 0x70, 0x73, 0x44, 0xa4, 0x09, 0x38, 0x22, 0x29, 0x9f, 0x31, 0xd0, 0x08, 0x2e, 0xfa, 0x98, 0xec, 0x4e, 0x6c, 0x89], [0x6c, 0xff, 0x5c, 0x3b, 0xa8, 0x6c, 0x69, 0xea, 0x4b, 0x73, 0x76, 0xf3, 0x1a, 0x9b, 0xcb, 0x4f, 0x74, 0xc1, 0x97, 0x60, 0x89, 0xb2, 0xd9, 0x96, 0x3d, 0xa2, 0xe5, 0x54, 0x3e, 0x17, 0x77, 0x69, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xfe, 0xba, 0xae, 0xdc, 0xe6, 0xaf, 0x48, 0xa0, 0x3b, 0xbf, 0xd2, 0x5e, 0x8c, 0xd0, 0x36, 0x41, 0x41], false),
        ([0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xfe, 0xff, 0xff, 0xfc, 0x30], [0x24, 0x3f, 0x6a, 0x88, 0x85, 0xa3, 0x08, 0xd3, 0x13, 0x19, 0x8a, 0x2e, 0x03, 0x70, 0x73, 0x44, 0xa4, 0x09, 0x38, 0x22, 0x29, 0x9f, 0x31, 0xd0, 0x08, 0x2e, 0xfa, 0x98, 0xec, 0x4e, 0x6c, 0x89], [0x6c, 0xff, 0x5c, 0x3b, 0xa8, 0x6c, 0x69, 0xea, 0x4b, 0x73, 0x76, 0xf3, 0x1a, 0x9b, 0xcb, 0x4f, 0x74, 0xc1, 0x97, 0x60, 0x89, 0xb2, 0xd9, 0x96, 0x3d, 0xa2, 0xe5, 0x54, 0x3e, 0x17, 0x77, 0x69, 0x69, 0xe8, 0x9b, 0x4c, 0x55, 0x64, 0xd0, 0x03, 0x49, 0x10, 0x6b, 0x84, 0x97, 0x78, 0x5d, 0xd7, 0xd1, 0xd7, 0x13, 0xa8, 0xae, 0x82, 0xb3, 0x2f, 0xa7, 0x9d, 0x5f, 0x7f, 0xc4, 0x07, 0xd3, 0x9b], false)
    ])
    func verifySchnorrSig(publicKeyBytes: [UInt8], hashBytes: [UInt8], sigBytes: [UInt8], expectedResult: Bool) throws {
        let publicKeyData = Data(publicKeyBytes)
        let hash = Data(hashBytes)
        let sigData = Data(sigBytes)
        let publicKey = try #require(PublicKey(xOnly: publicKeyData))
        let sig = try #require(AnySig(sigData, type: .schnorr))
        #expect(sig.verify(hash: hash, publicKey: publicKey) == expectedResult)
    }
}
