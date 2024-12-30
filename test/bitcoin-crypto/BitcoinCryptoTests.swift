import Foundation
import Testing
import BitcoinCrypto

struct BitcoinCryptoTests {

    @Test func basics() async throws {
        let secretKey = SecretKey()

        let publicKey = secretKey.publicKey
        #expect(publicKey.matches(secretKey))

        let publicKeyCopy = PublicKey(secretKey)
        #expect(publicKey == publicKeyCopy)

        let message = "Hello, Bitcoin!"
        let sig = try #require(secretKey.sign(message, sigType: .schnorr))

        let isSignatureValid = publicKey.verify(sig, for: message)
        #expect(isSignatureValid)

        // ECDSA signature
        let sigECDSA = try #require(secretKey.sign(message, sigType: .compact))

        let isECDSASignatureValid = sigECDSA.verify(message: message, publicKey: publicKey)
        #expect(isECDSASignatureValid)
    }

    @Test func deserialization() async throws {
        let secretKey = try #require(SecretKey("49c3a44bf0e2b81e4a741102b408e311702c7e3be0215ca2c466b3b54d9c5463"))

        let publicKey = try #require(PublicKey("02c8d21f79529deeaa2769198d3df6209a064c9915ae557f7a9d01d724590d6334"))
        #expect(publicKey.matches(secretKey))

        let publicKeyCopy = PublicKey(secretKey)
        #expect(publicKey == publicKeyCopy)

        let message = "Hello, Bitcoin!"
        let sig = try #require(Signature("c211fc6a0d3b89170af26e1bfcc511de813a01e855b862788e1fa576280a7abc202f1bc1535dc51c54ecbae48dcc9b5752ffa4a8852f7d81aafb695f5efd8876", type: .schnorr))

        let isSignatureValid = publicKey.verify(sig, for: message)
        #expect(isSignatureValid)

        let sigCopy = try #require(secretKey.sign(message, sigType: .schnorr))
        #expect(sig == sigCopy)

        // ECDSA signature
        let sigECDSA = try #require(Signature("151756497fb7ad7b910341814aed135e5835b8fa3c6b63132cb36f4b453bdc3c61defc72d99ef44170bd130ef66a9ef4122c96e623d20bff79d0b740c29af2af", type: .compact))

        let isECDSASignatureValid = sigECDSA.verify(message: message, publicKey: publicKey)
        #expect(isECDSASignatureValid)

        let sigECDSACopy = try #require(secretKey.sign(message, sigType: .compact))
        #expect(sigECDSA == sigECDSACopy)
    }

    @Test func serializationRoundTrips() async throws {
        let secretKey = SecretKey()
        let secretKey2 = try #require(SecretKey(secretKey.description))
        #expect(secretKey == secretKey2)

        let publicKey = secretKey.publicKey
        let publicKey2 = try #require(PublicKey(publicKey.description))
        #expect(publicKey == publicKey2)
    }

    @Test func schnorr() throws {
        let secretKey = SecretKey()

        let message = "Hello, Bitcoin!"
        let sig = try #require(secretKey.sign(message, sigType: .schnorr))

        let publicKey = secretKey.publicKey
        #expect(publicKey.matches(secretKey))
        let valid = publicKey.verify(sig, for: message)
        #expect(valid)

        // Tweak
        let tweak = Data(Hash256.hash(data: "I am Satoshi.".data(using: .utf8)!))
        let tweakedSecretKey = secretKey.tweakXOnly(tweak)
        let sig2 = try #require(tweakedSecretKey.sign(message, sigType: .schnorr))

        let tweakedPublicKey = publicKey.tweakXOnly(tweak)
        let valid2 = tweakedPublicKey.verify(sig2, for: message)
        #expect(valid2)

        let valid3 = publicKey.verify(sig2, for: message)
        #expect(!valid3)
    }

    @Test func recoverable() throws {
        let secretKey = SecretKey()

        let message = "Hello, Bitcoin!"
        let sig = try #require(secretKey.sign(message, sigType: .recoverable))

        let recovered = try #require(sig.recoverPublicKey(from: message))
        #expect(recovered.matches(secretKey))

        let valid = recovered.verify(sig, for: message)
        #expect(valid)

        let publicKey = secretKey.publicKey
        #expect(publicKey == recovered)
    }

    @Test func secretKeyDeserialization() async throws {
        let hex = "49c3a44bf0e2b81e4a741102b408e311702c7e3be0215ca2c466b3b54d9c5463"
        let secretKey = try #require(SecretKey(hex))

        let hex2 = secretKey.description
        #expect(hex2 == hex)

        let secretKey2 = try #require(SecretKey(hex))
        #expect(secretKey == secretKey2)
    }
}
