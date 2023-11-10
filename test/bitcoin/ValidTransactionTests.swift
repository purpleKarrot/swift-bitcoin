import XCTest
@testable import Bitcoin

final class ValidTransactionTests: XCTestCase {

    override class func setUp() {
        eccStart()
    }

    override class func tearDown() {
        eccStop()
    }

    func testValidTransactions() throws {
        for vector in testVectors {
            guard
                let expectedTransactionData = Data(hex: vector.serializedTransaction),
                let tx = Transaction(expectedTransactionData)
            else {
                XCTFail(); return
            }
            let previousOutputs = vector.previousOutputs.map { previousOutput in
                Output(value: previousOutput.amount, script: ParsedScript(previousOutput.scriptOperations))
            }
            XCTAssertNoThrow(try tx.check())
            var excludeFlags = Set(vector.verifyFlags.split(separator: ","))
            excludeFlags.remove("NONE")
            var config = ScriptConfigurarion.standard
            if excludeFlags.contains("STRICTENC") {
                config.strictEncoding = false
            }
            if excludeFlags.contains("LOW_S") {
                config.lowS = false
            }
            if excludeFlags.contains("DERSIG") {
                config.strictDER = false
            }
            if excludeFlags.contains("NULLDUMMY") {
                config.nullDummy = false
            }
            if excludeFlags.contains("CLEANSTACK") {
                config.cleanStack = false
            }
            if excludeFlags.contains("P2SH") {
                config.payToScriptHash = false
            }
            if excludeFlags.contains("SIGPUSHONLY") {
                config.pushOnly = false
            }
            if excludeFlags.contains("CHECKLOCKTIMEVERIFY") {
                config.checkLockTimeVerify = false
            }
            if excludeFlags.contains("CHECKSEQUENCEVERIFY") {
                config.checkSequenceVerify = false
            }
            let result = tx.verify(previousOutputs: previousOutputs, configuration: config)
            XCTAssert(result)
            if !excludeFlags.isEmpty && !excludeFlags.contains("CONST_SCRIPTCODE") && !excludeFlags.contains("NULLFAIL") && !excludeFlags.contains("MINIMALDATA") {
                 let failure = tx.verify(previousOutputs: previousOutputs, configuration: .standard)
                 XCTAssertFalse(failure)
            }
        }
    }
}

fileprivate struct TestVector {

    struct PreviousOutput {
        let transactionIdentifier: String
        let outputIndex: Int
        let amount: Int
        let scriptOperations: [ScriptOperation]
    }

    let previousOutputs: [PreviousOutput]
    let serializedTransaction: String
    let verifyFlags: String
}

fileprivate let testVectors: [TestVector] = [

    // MARK: - Valid transactions
    // The following are deserialized transactions which are valid.

    // The following is 23b397edccd3740a74adb603c9756370fafcde9bcc4483eb271ecad09a94dd63
    // It is of particular interest because it contains an invalidly-encoded signature which OpenSSL accepts
    // See http://r6.ca/blog/20111119T211504Z.html
    // It is also the first OP_CHECKMULTISIG transaction in standard form
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "60a20bd93aa49ab4b28d514ec10b06e1829ce6818ec06cd3aabd013ebcdc4bb1",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1),
                    .pushBytes(.init(hex: "04cc71eb30d653c0c3163990c47b976f3fb3f37cccdcbedb169a1dfef58bbfbfaff7d8a473e7e2e6d317b87bafe8bde97e3cf8f065dec022b51d11fcdd0d348ac4")!),
                    .pushBytes(.init(hex: "0461cbdcc5409fb4b4d42b51d33381354d80e550078cb532a34bfa2fcfdeb7d76519aecc62770f5b0e4ef8551946d8a540911abe3e7854a26f39f58b25c15342af")!),
                    .constant(2),
                    .checkMultiSig
                ]
            )
        ],
        serializedTransaction: "0100000001b14bdcbc3e01bdaad36cc08e81e69c82e1060bc14e518db2b49aa43ad90ba26000000000490047304402203f16c6f40162ab686621ef3000b04e75418a0c0cb2d8aebeac894ae360ac1e780220ddc15ecdfc3507ac48e1681a33eb60996631bf6bf5bc0a0682c4db743ce7ca2b01ffffffff0140420f00000000001976a914660d4ef3a743e3e696ad990364e555c271ad504b88ac00000000",
        verifyFlags: "DERSIG,LOW_S,STRICTENC"
    ),

    // The following is a tweaked form of 23b397edccd3740a74adb603c9756370fafcde9bcc4483eb271ecad09a94dd63
    // It is an OP_CHECKMULTISIG with an arbitrary extra byte stuffed into the signature at pos length - 2
    // The dummy byte is fine however, so the NULLDUMMY flag should be happy
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "60a20bd93aa49ab4b28d514ec10b06e1829ce6818ec06cd3aabd013ebcdc4bb1",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1),
                    .pushBytes(.init(hex: "04cc71eb30d653c0c3163990c47b976f3fb3f37cccdcbedb169a1dfef58bbfbfaff7d8a473e7e2e6d317b87bafe8bde97e3cf8f065dec022b51d11fcdd0d348ac4")!),
                    .pushBytes(.init(hex: "0461cbdcc5409fb4b4d42b51d33381354d80e550078cb532a34bfa2fcfdeb7d76519aecc62770f5b0e4ef8551946d8a540911abe3e7854a26f39f58b25c15342af")!),
                    .constant(2),
                    .checkMultiSig
                ]
            )
        ],
        serializedTransaction: "0100000001b14bdcbc3e01bdaad36cc08e81e69c82e1060bc14e518db2b49aa43ad90ba260000000004a0048304402203f16c6f40162ab686621ef3000b04e75418a0c0cb2d8aebeac894ae360ac1e780220ddc15ecdfc3507ac48e1681a33eb60996631bf6bf5bc0a0682c4db743ce7ca2bab01ffffffff0140420f00000000001976a914660d4ef3a743e3e696ad990364e555c271ad504b88ac00000000",
        verifyFlags: "DERSIG,LOW_S,STRICTENC"
    ),

    // The following is a tweaked form of 23b397edccd3740a74adb603c9756370fafcde9bcc4483eb271ecad09a94dd63
    // It is an OP_CHECKMULTISIG with the dummy value set to something other than an empty string
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "60a20bd93aa49ab4b28d514ec10b06e1829ce6818ec06cd3aabd013ebcdc4bb1",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1),
                    .pushBytes(.init(hex: "04cc71eb30d653c0c3163990c47b976f3fb3f37cccdcbedb169a1dfef58bbfbfaff7d8a473e7e2e6d317b87bafe8bde97e3cf8f065dec022b51d11fcdd0d348ac4")!),
                    .pushBytes(.init(hex: "0461cbdcc5409fb4b4d42b51d33381354d80e550078cb532a34bfa2fcfdeb7d76519aecc62770f5b0e4ef8551946d8a540911abe3e7854a26f39f58b25c15342af")!),
                    .constant(2),
                    .checkMultiSig
                ]
            )
        ],
        serializedTransaction: "0100000001b14bdcbc3e01bdaad36cc08e81e69c82e1060bc14e518db2b49aa43ad90ba260000000004a01ff47304402203f16c6f40162ab686621ef3000b04e75418a0c0cb2d8aebeac894ae360ac1e780220ddc15ecdfc3507ac48e1681a33eb60996631bf6bf5bc0a0682c4db743ce7ca2b01ffffffff0140420f00000000001976a914660d4ef3a743e3e696ad990364e555c271ad504b88ac00000000",
        verifyFlags: "DERSIG,LOW_S,STRICTENC,NULLDUMMY"
    ),

    // As above, but using an OP_1
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "60a20bd93aa49ab4b28d514ec10b06e1829ce6818ec06cd3aabd013ebcdc4bb1",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1),
                    .pushBytes(.init(hex: "04cc71eb30d653c0c3163990c47b976f3fb3f37cccdcbedb169a1dfef58bbfbfaff7d8a473e7e2e6d317b87bafe8bde97e3cf8f065dec022b51d11fcdd0d348ac4")!),
                    .pushBytes(.init(hex: "0461cbdcc5409fb4b4d42b51d33381354d80e550078cb532a34bfa2fcfdeb7d76519aecc62770f5b0e4ef8551946d8a540911abe3e7854a26f39f58b25c15342af")!),
                    .constant(2),
                    .checkMultiSig
                ]
            )
        ],
        serializedTransaction: "0100000001b14bdcbc3e01bdaad36cc08e81e69c82e1060bc14e518db2b49aa43ad90ba26000000000495147304402203f16c6f40162ab686621ef3000b04e75418a0c0cb2d8aebeac894ae360ac1e780220ddc15ecdfc3507ac48e1681a33eb60996631bf6bf5bc0a0682c4db743ce7ca2b01ffffffff0140420f00000000001976a914660d4ef3a743e3e696ad990364e555c271ad504b88ac00000000",
        verifyFlags: "DERSIG,LOW_S,STRICTENC,NULLDUMMY"
    ),

    // As above, but using an OP_1NEGATE
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "60a20bd93aa49ab4b28d514ec10b06e1829ce6818ec06cd3aabd013ebcdc4bb1",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1),
                    .pushBytes(.init(hex: "04cc71eb30d653c0c3163990c47b976f3fb3f37cccdcbedb169a1dfef58bbfbfaff7d8a473e7e2e6d317b87bafe8bde97e3cf8f065dec022b51d11fcdd0d348ac4")!),
                    .pushBytes(.init(hex: "0461cbdcc5409fb4b4d42b51d33381354d80e550078cb532a34bfa2fcfdeb7d76519aecc62770f5b0e4ef8551946d8a540911abe3e7854a26f39f58b25c15342af")!),
                    .constant(2),
                    .checkMultiSig
                ]
            )
        ],
        serializedTransaction: "0100000001b14bdcbc3e01bdaad36cc08e81e69c82e1060bc14e518db2b49aa43ad90ba26000000000494f47304402203f16c6f40162ab686621ef3000b04e75418a0c0cb2d8aebeac894ae360ac1e780220ddc15ecdfc3507ac48e1681a33eb60996631bf6bf5bc0a0682c4db743ce7ca2b01ffffffff0140420f00000000001976a914660d4ef3a743e3e696ad990364e555c271ad504b88ac00000000",
        verifyFlags: "DERSIG,LOW_S,STRICTENC,NULLDUMMY"
    ),

    // The following is c99c49da4c38af669dea436d3e73780dfdb6c1ecf9958baa52960e8baee30e73
    // It is of interest because it contains a 0-sequence as well as a signature of SIGHASH type 0 (which is not a real type)
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "406b2b06bcd34d3c8733e6b79f7a394c8a431fbf4ff5ac705c93f4076bb77602",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "dc44b1164188067c3a32d4780f5996fa14a4f2d9")!),
                    .equalVerify,
                    .checkSig
                ]
            )
        ],
        serializedTransaction: "01000000010276b76b07f4935c70acf54fbf1f438a4c397a9fb7e633873c4dd3bc062b6b40000000008c493046022100d23459d03ed7e9511a47d13292d3430a04627de6235b6e51a40f9cd386f2abe3022100e7d25b080f0bb8d8d5f878bba7d54ad2fda650ea8d158a33ee3cbd11768191fd004104b0e2c879e4daf7b9ab68350228c159766676a14f5815084ba166432aab46198d4cca98fa3e9981d0a90b2effc514b76279476550ba3663fdcaff94c38420e9d5000000000100093d00000000001976a9149a7b0f3b80c6baaeedce0a0842553800f832ba1f88ac00000000",
        verifyFlags: "LOW_S,STRICTENC"
    ),

    // A nearly-standard transaction with CHECKSIGVERIFY 1 instead of CHECKSIG
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "5b6462475454710f3c22f5fdf0b40704c92f25c3")!),
                    .equalVerify,
                    .checkSigVerify,
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000006a473044022067288ea50aa799543a536ff9306f8e1cba05b9c6b10951175b924f96732555ed022026d7b5265f38d21541519e4a1e55044d5b9e17e15cdbaf29ae3792e99e883e7a012103ba8c8b86dea131c22ab967e6dd99bdae8eff7a1f75a2c35f1f944109e3fe5e22ffffffff010000000000000000015100000000",
        verifyFlags: "NONE"
    ),

    // Same as above, but with the signature duplicated in the scriptPubKey with the proper pushdata prefix
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "5b6462475454710f3c22f5fdf0b40704c92f25c3")!),
                    .equalVerify,
                    .checkSigVerify,
                    .constant(1),
                    .pushBytes(.init(hex: "3044022067288ea50aa799543a536ff9306f8e1cba05b9c6b10951175b924f96732555ed022026d7b5265f38d21541519e4a1e55044d5b9e17e15cdbaf29ae3792e99e883e7a01")!)
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000006a473044022067288ea50aa799543a536ff9306f8e1cba05b9c6b10951175b924f96732555ed022026d7b5265f38d21541519e4a1e55044d5b9e17e15cdbaf29ae3792e99e883e7a012103ba8c8b86dea131c22ab967e6dd99bdae8eff7a1f75a2c35f1f944109e3fe5e22ffffffff010000000000000000015100000000",
        verifyFlags: "CLEANSTACK,CONST_SCRIPTCODE"
    ),

    // The following is f7fdd091fa6d8f5e7a8c2458f5c38faffff2d3f1406b6e4fe2c99dcc0d2d1cbb
    // It caught a bug in the workaround for 23b397edccd3740a74adb603c9756370fafcde9bcc4483eb271ecad09a94dd63 in an overly simple implementation. In a signature, it contains an ASN1 integer which isn't strict-DER conformant due to being negative, which doesn't make sense in a signature. Before BIP66 activated, it was a valid signature. After it activated, it's not valid any more.
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "b464e85df2a238416f8bdae11d120add610380ea07f4ef19c5f9dfd472f96c3d",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "bef80ecf3a44500fda1bc92176e442891662aed2")!),
                    .equalVerify,
                    .checkSig
                ]
            ),
            .init(
                transactionIdentifier: "b7978cc96e59a8b13e0865d3f95657561a7f725be952438637475920bac9eb21",
                outputIndex: 1,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "bef80ecf3a44500fda1bc92176e442891662aed2")!),
                    .equalVerify,
                    .checkSig
                ]
            )
        ],
        serializedTransaction: "01000000023d6cf972d4dff9c519eff407ea800361dd0a121de1da8b6f4138a2f25de864b4000000008a4730440220ffda47bfc776bcd269da4832626ac332adfca6dd835e8ecd83cd1ebe7d709b0e022049cffa1cdc102a0b56e0e04913606c70af702a1149dc3b305ab9439288fee090014104266abb36d66eb4218a6dd31f09bb92cf3cfa803c7ea72c1fc80a50f919273e613f895b855fb7465ccbc8919ad1bd4a306c783f22cd3227327694c4fa4c1c439affffffff21ebc9ba20594737864352e95b727f1a565756f9d365083eb1a8596ec98c97b7010000008a4730440220503ff10e9f1e0de731407a4a245531c9ff17676eda461f8ceeb8c06049fa2c810220c008ac34694510298fa60b3f000df01caa244f165b727d4896eb84f81e46bcc4014104266abb36d66eb4218a6dd31f09bb92cf3cfa803c7ea72c1fc80a50f919273e613f895b855fb7465ccbc8919ad1bd4a306c783f22cd3227327694c4fa4c1c439affffffff01f0da5200000000001976a914857ccd42dded6df32949d4646dfa10a92458cfaa88ac00000000",
        verifyFlags: "DERSIG,LOW_S,STRICTENC"
    ),

    // The following tests for the presence of a bug in the handling of `SIGHASH_SINGLE`
    // It results in signing the constant 1, instead of something generated based on the transaction
    // when the input doing the signing has an index greater than the maximum output index.
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000200",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1)
                ]
            ),
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "e52b482f2faa8ecbf0db344f93c84ac908557f33")!),
                    .equalVerify,
                    .checkSig
                ]
            )
        ],
        serializedTransaction: "01000000020002000000000000000000000000000000000000000000000000000000000000000000000151ffffffff0001000000000000000000000000000000000000000000000000000000000000000000006b483045022100c9cdd08798a28af9d1baf44a6c77bcc7e279f47dc487c8c899911bc48feaffcc0220503c5c50ae3998a733263c5c0f7061b483e2b56c4c41b456e7d2f5a78a74c077032102d5c25adb51b61339d2b05315791e21bbe80ea470a49db0135720983c905aace0ffffffff010000000000000000015100000000",
        verifyFlags: "CLEANSTACK"
    ),

    // The following tests SIGHASH_SINGLE|SIGHASHANYONECANPAY inputs
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "437a1002eb125dec0f93f635763e0ae45f28ff8e81d82945753d0107611cd390",
                outputIndex: 1,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "383fb81cb0a3fc724b5e08cf8bbd404336d711f6")!),
                    .equalVerify,
                    .checkSig
                ]
            ),
            .init(
                transactionIdentifier: "2d48d32ccad087bcda0ac5b31555bd58d1d2568184cbc8e752dd2be2684af03f",
                outputIndex: 1,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "275ec2a233e5b23d43fa19e7bf9beb0cb3996117")!),
                    .equalVerify,
                    .checkSig
                ]
            ),
            .init(
                transactionIdentifier: "c76168ef1a272a4f176e55e73157ecfce040cfad16a5272f6296eb7089dca846",
                outputIndex: 1,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "34fea2c5a75414fd945273ae2d029ce1f28dafcf")!),
                    .equalVerify,
                    .checkSig
                ]
            )
        ],
        serializedTransaction: "010000000390d31c6107013d754529d8818eff285fe40a3e7635f6930fec5d12eb02107a43010000006b483045022100f40815ae3c81a0dd851cc8d376d6fd226c88416671346a9033468cca2cdcc6c202204f764623903e6c4bed1b734b75d82c40f1725e4471a55ad4f51218f86130ac038321033d710ab45bb54ac99618ad23b3c1da661631aa25f23bfe9d22b41876f1d46e4effffffff3ff04a68e22bdd52e7c8cb848156d2d158bd5515b3c50adabc87d0ca2cd3482d010000006a4730440220598d263c107004008e9e26baa1e770be30fd31ee55ded1898f7c00da05a75977022045536bead322ca246779698b9c3df3003377090f41afeca7fb2ce9e328ec4af2832102b738b531def73020bd637f32935924cc88549c8206976226d968edd3a42fc2d7ffffffff46a8dc8970eb96622f27a516adcf40e0fcec5731e7556e174f2a271aef6861c7010000006b483045022100c5b90a777a9fdc90c208dbef7290d1fc1be651f47151ee4ccff646872a454cf90220640cfbc4550446968fbbe9d12528f3adf7d87b31541569c59e790db8a220482583210391332546e22bbe8fe3af54addfad6f8b83d05fa4f5e047593d4c07ae938795beffffffff028036be26000000001976a914ddfb29efad43a667465ac59ff14dc6442a1adfca88ac3d5cba01000000001976a914b64dde7a505a13ca986c40e86e984a8dc81368b688ac00000000",
        verifyFlags: "NONE"
    ),

    // A valid P2SH Transaction using the standard transaction type put forth in BIP 16
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .hash160,
                    .pushBytes(.init(hex: "8febbed40483661de6958d957412f82deed8e2f7")!),
                    .equal
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000006e493046022100c66c9cdf4c43609586d15424c54707156e316d88b0a1534c9e6b0d4f311406310221009c0fe51dbc9c4ab7cc25d3fdbeccf6679fe6827f08edf2b4a9f16ee3eb0e438a0123210338e8034509af564c62644c07691942e0c056752008a173c89f60ab2a88ac2ebfacffffffff010000000000000000015100000000",
        verifyFlags: "LOW_S"
    ),

    // MARK: - Tests for CheckTransaction()

    // MAX_MONEY output
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .hash160,
                    .pushBytes(.init(hex: "32afac281462b822adbec5094b8d4d337dd5bd6a")!),
                    .equal
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000006e493046022100e1eadba00d9296c743cb6ecc703fd9ddc9b3cd12906176a226ae4c18d6b00796022100a71aef7d2874deff681ba6080f1b278bac7bb99c61b08a85f4311970ffe7f63f012321030c0588dc44d92bdcbf8e72093466766fdc265ead8db64517b0c542275b70fffbacffffffff010040075af0750700015100000000",
        verifyFlags: "LOW_S"
    ),

    // MAX_MONEY output + 0 output
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .hash160,
                    .pushBytes(.init(hex: "b558cbf4930954aa6a344363a15668d7477ae716")!),
                    .equal
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000006d483045022027deccc14aa6668e78a8c9da3484fbcd4f9dcc9bb7d1b85146314b21b9ae4d86022100d0b43dece8cfb07348de0ca8bc5b86276fa88f7f2138381128b7c36ab2e42264012321029bb13463ddd5d2cc05da6e84e37536cb9525703cfd8f43afdb414988987a92f6acffffffff020040075af075070001510000000000000000015100000000",
        verifyFlags: "LOW_S"
    ),

    // Coinbase of size 2
    // Note the input is just required to make the tester happy
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000000",
                outputIndex: -1,
                amount: 0,
                scriptOperations: [
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff025151ffffffff010000000000000000015100000000",
        verifyFlags: "CLEANSTACK"
    ),

    // Coinbase of size 100
    // Note the input is just required to make the tester happy
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000000",
                outputIndex: -1,
                amount: 0,
                scriptOperations: [
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff6451515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151ffffffff010000000000000000015100000000",
        verifyFlags: "CLEANSTACK"
    ),

    // Simple transaction with first input is signed with SIGHASH_ALL, second with SIGHASH_ANYONECANPAY
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(hex: "035e7f0d4d0841bcd56c39337ed086b1a633ee770c1ffdd94ac552a95ac2ce0efc")!),
                    .checkSig
                ]
            ),
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000200",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(hex: "035e7f0d4d0841bcd56c39337ed086b1a633ee770c1ffdd94ac552a95ac2ce0efc")!),
                    .checkSig
                ]
            )
        ],
        serializedTransaction: "010000000200010000000000000000000000000000000000000000000000000000000000000000000049483045022100d180fd2eb9140aeb4210c9204d3f358766eb53842b2a9473db687fa24b12a3cc022079781799cd4f038b85135bbe49ec2b57f306b2bb17101b17f71f000fcab2b6fb01ffffffff0002000000000000000000000000000000000000000000000000000000000000000000004847304402205f7530653eea9b38699e476320ab135b74771e1c48b81a5d041e2ca84b9be7a802200ac8d1f40fb026674fe5a5edd3dea715c27baa9baca51ed45ea750ac9dc0a55e81ffffffff010100000000000000015100000000",
        verifyFlags: "NONE"
    ),

    // Same as above, but we change the sequence number of the first input to check that SIGHASH_ANYONECANPAY is being followed
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(hex: "035e7f0d4d0841bcd56c39337ed086b1a633ee770c1ffdd94ac552a95ac2ce0efc")!),
                    .checkSig
                ]
            ),
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000200",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(hex: "035e7f0d4d0841bcd56c39337ed086b1a633ee770c1ffdd94ac552a95ac2ce0efc")!),
                    .checkSig
                ]
            )
        ],
        serializedTransaction: "01000000020001000000000000000000000000000000000000000000000000000000000000000000004948304502203a0f5f0e1f2bdbcd04db3061d18f3af70e07f4f467cbc1b8116f267025f5360b022100c792b6e215afc5afc721a351ec413e714305cb749aae3d7fee76621313418df101010000000002000000000000000000000000000000000000000000000000000000000000000000004847304402205f7530653eea9b38699e476320ab135b74771e1c48b81a5d041e2ca84b9be7a802200ac8d1f40fb026674fe5a5edd3dea715c27baa9baca51ed45ea750ac9dc0a55e81ffffffff010100000000000000015100000000",
        verifyFlags: "LOW_S"
    ),

    // afd9c17f8913577ec3509520bd6e5d63e9c0fd2a5f70c787993b097ba6ca9fae which has several SIGHASH_SINGLE signatures
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "63cfa5a09dc540bf63e53713b82d9ea3692ca97cd608c384f2aa88e51a0aac70",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "dcf72c4fd02f5a987cf9b02f2fabfcac3341a87d")!),
                    .equalVerify,
                    .checkSig
                ]
            ),
            .init(
                transactionIdentifier: "04e8d0fcf3846c6734477b98f0f3d4badfb78f020ee097a0be5fe347645b817d",
                outputIndex: 1,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "dcf72c4fd02f5a987cf9b02f2fabfcac3341a87d")!),
                    .equalVerify,
                    .checkSig
                ]
            ),
            .init(
                transactionIdentifier: "ee1377aff5d0579909e11782e1d2f5f7b84d26537be7f5516dd4e43373091f3f",
                outputIndex: 1,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "dcf72c4fd02f5a987cf9b02f2fabfcac3341a87d")!),
                    .equalVerify,
                    .checkSig
                ]
            )
        ],
        serializedTransaction: "010000000370ac0a1ae588aaf284c308d67ca92c69a39e2db81337e563bf40c59da0a5cf63000000006a4730440220360d20baff382059040ba9be98947fd678fb08aab2bb0c172efa996fd8ece9b702201b4fb0de67f015c90e7ac8a193aeab486a1f587e0f54d0fb9552ef7f5ce6caec032103579ca2e6d107522f012cd00b52b9a65fb46f0c57b9b8b6e377c48f526a44741affffffff7d815b6447e35fbea097e00e028fb7dfbad4f3f0987b4734676c84f3fcd0e804010000006b483045022100c714310be1e3a9ff1c5f7cacc65c2d8e781fc3a88ceb063c6153bf950650802102200b2d0979c76e12bb480da635f192cc8dc6f905380dd4ac1ff35a4f68f462fffd032103579ca2e6d107522f012cd00b52b9a65fb46f0c57b9b8b6e377c48f526a44741affffffff3f1f097333e4d46d51f5e77b53264db8f7f5d2e18217e1099957d0f5af7713ee010000006c493046022100b663499ef73273a3788dea342717c2640ac43c5a1cf862c9e09b206fcb3f6bb8022100b09972e75972d9148f2bdd462e5cb69b57c1214b88fc55ca638676c07cfc10d8032103579ca2e6d107522f012cd00b52b9a65fb46f0c57b9b8b6e377c48f526a44741affffffff0380841e00000000001976a914bfb282c70c4191f45b5a6665cad1682f2c9cfdfb88ac80841e00000000001976a9149857cc07bed33a5cf12b9c5e0500b675d500c81188ace0fd1c00000000001976a91443c52850606c872403c0601e69fa34b26f62db4a88ac00000000",
        verifyFlags: "LOW_S"
    ),

    // ddc454a1c0c35c188c98976b17670f69e586d9c0f3593ea879928332f0a069e7, which spends an input that pushes using a PUSHDATA1 that is negative when read as signed
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "c5510a5dd97a25f43175af1fe649b707b1df8e1a41489bac33a23087027a2f48",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushData1(.init(hex: "606563686f2022553246736447566b58312b5a536e587574356542793066794778625456415675534a6c376a6a334878416945325364667657734f53474f36633338584d7439435c6e543249584967306a486956304f376e775236644546673d3d22203e20743b206f70656e73736c20656e63202d7061737320706173733a5b314a564d7751432d707269766b65792d6865785d202d64202d6165732d3235362d636263202d61202d696e207460")!),
                    .drop,
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "bfd7436b6265aa9de506f8a994f881ff08cc2872")!),
                    .equalVerify,
                    .checkSig
                ]
            )
        ],
        serializedTransaction: "0100000001482f7a028730a233ac9b48411a8edfb107b749e61faf7531f4257ad95d0a51c5000000008b483045022100bf0bbae9bde51ad2b222e87fbf67530fbafc25c903519a1e5dcc52a32ff5844e022028c4d9ad49b006dd59974372a54291d5764be541574bb0c4dc208ec51f80b7190141049dd4aad62741dc27d5f267f7b70682eee22e7e9c1923b9c0957bdae0b96374569b460eb8d5b40d972e8c7c0ad441de3d94c4a29864b212d56050acb980b72b2bffffffff0180969800000000001976a914e336d0017a9d28de99d16472f6ca6d5a3a8ebc9988ac00000000",
        verifyFlags: "NONE"
    ),

    // Correct signature order
    // Note the input is just required to make the tester happy
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "b3da01dd4aae683c7aee4d5d8b52a540a508e1115f77cd7fa9a291243f501223",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .hash160,
                    .pushBytes(.init(hex: "b1ce99298d5f07364b57b1e5c9cc00be0b04a954")!),
                    .equal
                ]
            )
        ],
        serializedTransaction: "01000000012312503f2491a2a97fcd775f11e108a540a5528b5d4dee7a3c68ae4add01dab300000000fdfe0000483045022100f6649b0eddfdfd4ad55426663385090d51ee86c3481bdc6b0c18ea6c0ece2c0b0220561c315b07cffa6f7dd9df96dbae9200c2dee09bf93cc35ca05e6cdf613340aa0148304502207aacee820e08b0b174e248abd8d7a34ed63b5da3abedb99934df9fddd65c05c4022100dfe87896ab5ee3df476c2655f9fbe5bd089dccbef3e4ea05b5d121169fe7f5f4014c695221031d11db38972b712a9fe1fc023577c7ae3ddb4a3004187d41c45121eecfdbb5b7210207ec36911b6ad2382860d32989c7b8728e9489d7bbc94a6b5509ef0029be128821024ea9fac06f666a4adc3fc1357b7bec1fd0bdece2b9d08579226a8ebde53058e453aeffffffff0180380100000000001976a914c9b99cddf847d10685a4fabaa0baf505f7c3dfab88ac00000000",
        verifyFlags: "LOW_S"
    ),

    // cc60b1f899ec0a69b7c3f25ddf32c4524096a9c5b01cbd84c6d0312a0c478984, which is a fairly strange transaction which relies on OP_CHECKSIG returning 0 when checking a completely invalid sig of length 0
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "cbebc4da731e8995fe97f6fadcd731b36ad40e5ecb31e38e904f6e5982fa09f7",
                outputIndex: 0,
                amount: 0,
                scriptOperations: ParsedScript(.init(hex: "2102085c6600657566acc2d6382a47bc3f324008d2aa10940dd7705a48aa2a5a5e33ac7c2103f5d0fb955f95dd6be6115ce85661db412ec6a08abcbfce7da0ba8297c6cc0ec4ac7c5379a820d68df9e32a147cffa36193c6f7c43a1c8c69cda530e1c6db354bfabdcfefaf3c875379a820f531f3041d3136701ea09067c53e7159c8f9b2746a56c3d82966c54bbc553226879a5479827701200122a59a5379827701200122a59a6353798277537982778779679a68")!)!.operations
                // scriptPubKey: "02085c6600657566acc2d6382a47bc3f324008d2aa10940dd7705a48aa2a5a5e33 OP_CHECKSIG OP_SWAP 03f5d0fb955f95dd6be6115ce85661db412ec6a08abcbfce7da0ba8297c6cc0ec4 OP_CHECKSIG OP_SWAP 3 OP_PICK OP_SHA256 d68df9e32a147cffa36193c6f7c43a1c8c69cda530e1c6db354bfabdcfefaf3c OP_EQUAL 3 OP_PICK OP_SHA256 f531f3041d3136701ea09067c53e7159c8f9b2746a56c3d82966c54bbc553226 OP_EQUAL OP_BOOLAND 4 OP_PICK OP_SIZE OP_NIP 32 34 OP_WITHIN OP_BOOLAND 3 OP_PICK OP_SIZE OP_NIP 32 34 OP_WITHIN OP_BOOLAND OP_IF 3 OP_PICK OP_SIZE OP_NIP 3 OP_PICK OP_SIZE OP_NIP OP_EQUAL OP_PICK OP_ELSE OP_BOOLAND OP_ENDIF"
                // scriptSig: "ca42095840735e89283fec298e62ac2ddea9b5f34a8cbb7097ad965b87568100 1b1b01dc829177da4a14551d2fc96a9db00c6501edfa12f22cd9cefd335c227f 3045022100a9df60536df5733dd0de6bc921fab0b3eee6426501b43a228afa2c90072eb5ca02201c78b74266fac7d1db5deff080d8a403743203f109fbcabf6d5a760bf87386d2[ALL] 0"
            )
        ],
        serializedTransaction: "0100000001f709fa82596e4f908ee331cb5e0ed46ab331d7dcfaf697fe95891e73dac4ebcb000000008c20ca42095840735e89283fec298e62ac2ddea9b5f34a8cbb7097ad965b87568100201b1b01dc829177da4a14551d2fc96a9db00c6501edfa12f22cd9cefd335c227f483045022100a9df60536df5733dd0de6bc921fab0b3eee6426501b43a228afa2c90072eb5ca02201c78b74266fac7d1db5deff080d8a403743203f109fbcabf6d5a760bf87386d20100ffffffff01c075790000000000232103611f9a45c18f28f06f19076ad571c344c82ce8fcfe34464cf8085217a2d294a6ac00000000",
        verifyFlags: "CLEANSTACK"
    ),

    // Empty pubkey
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "229257c295e7f555421c1bfec8538dd30a4b5c37c1c8810bbe83cafa7811652c",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .zero,
                    .checkSig,
                    .not
                ]
            )
        ],
        serializedTransaction: "01000000012c651178faca83be0b81c8c1375c4b0ad38d53c8fe1b1c4255f5e795c25792220000000049483045022100d6044562284ac76c985018fc4a90127847708c9edb280996c507b28babdc4b2a02203d74eca3f1a4d1eea7ff77b528fde6d5dc324ec2dbfdb964ba885f643b9704cd01ffffffff010100000000000000232102c2410f8891ae918cab4ffc4bb4a3b0881be67c7a1e7faa8b5acf9ab8932ec30cac00000000",
        verifyFlags: "STRICTENC,NULLFAIL"
    ),

    // Empty signature
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "9ca93cfd8e3806b9d9e2ba1cf64e3cc6946ee0119670b1796a09928d14ea25f7",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(hex: "028a1d66975dbdf97897e3a4aef450ebeb5b5293e4a0b4a6d3a2daaa0b2b110e02")!),
                    .checkSig,
                    .not
                ]
            )
        ],
        serializedTransaction: "0100000001f725ea148d92096a79b1709611e06e94c63c4ef61cbae2d9b906388efd3ca99c000000000100ffffffff0101000000000000002321028a1d66975dbdf97897e3a4aef450ebeb5b5293e4a0b4a6d3a2daaa0b2b110e02ac00000000",
        verifyFlags: "NONE"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "444e00ed7840d41f20ecd9c11d3f91982326c731a02f3c05748414a4fa9e59be",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1),
                    .zero,
                    .pushBytes(.init(hex: "02136b04758b0b6e363e7a6fbe83aaf527a153db2b060d36cc29f7f8309ba6e458")!),
                    .constant(2),
                    .checkMultiSig
                ]
            )
        ],
        serializedTransaction: "0100000001be599efaa4148474053c2fa031c7262398913f1dc1d9ec201fd44078ed004e44000000004900473044022022b29706cb2ed9ef0cb3c97b72677ca2dfd7b4160f7b4beb3ba806aa856c401502202d1e52582412eba2ed474f1f437a427640306fd3838725fab173ade7fe4eae4a01ffffffff010100000000000000232103ac4bba7e7ca3e873eea49e08132ad30c7f03640b6539e9b59903cf14fd016bbbac00000000",
        verifyFlags: "NONE"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "e16abbe80bf30c080f63830c8dbf669deaef08957446e95940227d8c5e6db612",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1),
                    .pushBytes(.init(hex: "03905380c7013e36e6e19d305311c1b81fce6581f5ee1c86ef0627c68c9362fc9f")!),
                    .zero,
                    .constant(2),
                    .checkMultiSig
                ]
            )
        ],
        serializedTransaction: "010000000112b66d5e8c7d224059e946749508efea9d66bf8d0c83630f080cf30be8bb6ae100000000490047304402206ffe3f14caf38ad5c1544428e99da76ffa5455675ec8d9780fac215ca17953520220779502985e194d84baa36b9bd40a0dbd981163fa191eb884ae83fc5bd1c86b1101ffffffff010100000000000000232103905380c7013e36e6e19d305311c1b81fce6581f5ee1c86ef0627c68c9362fc9fac00000000",
        verifyFlags: "STRICTENC"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "ebbcf4bfce13292bd791d6a65a2a858d59adbf737e387e40370d4e64cc70efb0",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(2),
                    .pushBytes(.init(hex: "033bcaa0a602f0d44cc9d5637c6e515b0471db514c020883830b7cefd73af04194")!),
                    .pushBytes(.init(hex: "03a88b326f8767f4f192ce252afe33c94d25ab1d24f27f159b3cb3aa691ffe1423")!),
                    .constant(2),
                    .checkMultiSig,
                    .not
                ]
            )
        ],
        serializedTransaction: "0100000001b0ef70cc644e0d37407e387e73bfad598d852a5aa6d691d72b2913cebff4bceb000000004a00473044022068cd4851fc7f9a892ab910df7a24e616f293bcb5c5fbdfbc304a194b26b60fba022078e6da13d8cb881a22939b952c24f88b97afd06b4c47a47d7f804c9a352a6d6d0100ffffffff0101000000000000002321033bcaa0a602f0d44cc9d5637c6e515b0471db514c020883830b7cefd73af04194ac00000000",
        verifyFlags: "NULLFAIL"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "ba4cd7ae2ad4d4d13ebfc8ab1d93a63e4a6563f25089a18bf0fc68f282aa88c1",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(2),
                    .pushBytes(.init(hex: "037c615d761e71d38903609bf4f46847266edc2fb37532047d747ba47eaae5ffe1")!),
                    .pushBytes(.init(hex: "02edc823cd634f2c4033d94f5755207cb6b60c4b1f1f056ad7471c47de5f2e4d50")!),
                    .constant(2),
                    .checkMultiSig,
                    .not
                ]
            )
        ],
        serializedTransaction: "0100000001c188aa82f268fcf08ba18950f263654a3ea6931dabc8bf3ed1d4d42aaed74cba000000004b0000483045022100940378576e069aca261a6b26fb38344e4497ca6751bb10905c76bb689f4222b002204833806b014c26fd801727b792b1260003c55710f87c5adbd7a9cb57446dbc9801ffffffff0101000000000000002321037c615d761e71d38903609bf4f46847266edc2fb37532047d747ba47eaae5ffe1ac00000000",
        verifyFlags: "NULLFAIL"
    ),

    // MARK: - OP_CODESEPARATOR tests

    // Test that SignatureHash() removes OP_CODESEPARATOR with FindAndDelete()
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "bc7fd132fcf817918334822ee6d9bd95c889099c96e07ca2c1eb2cc70db63224",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .codeSeparator,
                    .pushBytes(.init(hex: "038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f22041")!),
                    .checkSig
                ]
            ),
        ],
        serializedTransaction: "01000000012432b60dc72cebc1a27ce0969c0989c895bdd9e62e8234839117f8fc32d17fbc000000004a493046022100a576b52051962c25e642c0fd3d77ee6c92487048e5d90818bcf5b51abaccd7900221008204f8fb121be4ec3b24483b1f92d89b1b0548513a134e345c5442e86e8617a501ffffffff010000000000000000016a00000000",
        verifyFlags: "CONST_SCRIPTCODE,LOW_S"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "83e194f90b6ef21fa2e3a365b63794fb5daa844bdc9b25de30899fcfe7b01047",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .codeSeparator,
                    .codeSeparator,
                    .pushBytes(.init(hex: "038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f22041")!),
                    .checkSig
                ]
            ),
        ],
        serializedTransaction: "01000000014710b0e7cf9f8930de259bdc4b84aa5dfb9437b665a3e3a21ff26e0bf994e183000000004a493046022100a166121a61b4eeb19d8f922b978ff6ab58ead8a5a5552bf9be73dc9c156873ea02210092ad9bc43ee647da4f6652c320800debcf08ec20a094a0aaf085f63ecb37a17201ffffffff010000000000000000016a00000000",
        verifyFlags: "CONST_SCRIPTCODE,LOW_S"
    ),

    // Hashed data starts at the CODESEPARATOR
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "326882a7f22b5191f1a0cc9962ca4b878cd969cf3b3a70887aece4d801a0ba5e",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(hex: "038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f22041")!),
                    .codeSeparator,
                    .checkSig
                ]
            ),
        ],
        serializedTransaction: "01000000015ebaa001d8e4ec7a88703a3bcf69d98c874bca6299cca0f191512bf2a7826832000000004948304502203bf754d1c6732fbf87c5dcd81258aefd30f2060d7bd8ac4a5696f7927091dad1022100f5bcb726c4cf5ed0ed34cc13dadeedf628ae1045b7cb34421bc60b89f4cecae701ffffffff010000000000000000016a00000000",
        verifyFlags: "CONST_SCRIPTCODE,LOW_S"
    ),

    // But only if execution has reached it
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "a955032f4d6b0c9bfe8cad8f00a8933790b9c1dc28c82e0f48e75b35da0e4944",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(hex: "038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f22041")!),
                    .checkSigVerify,
                    .codeSeparator,
                    .pushBytes(.init(hex: "038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f22041")!),
                    .checkSigVerify,
                    .codeSeparator,
                    .constant(1)
                ]
            ),
        ],
        serializedTransaction: "010000000144490eda355be7480f2ec828dcc1b9903793a8008fad8cfe9b0c6b4d2f0355a900000000924830450221009c0a27f886a1d8cb87f6f595fbc3163d28f7a81ec3c4b252ee7f3ac77fd13ffa02203caa8dfa09713c8c4d7ef575c75ed97812072405d932bd11e6a1593a98b679370148304502201e3861ef39a526406bad1e20ecad06be7375ad40ddb582c9be42d26c3a0d7b240221009d0a3985e96522e59635d19cc4448547477396ce0ef17a58e7d74c3ef464292301ffffffff010000000000000000016a00000000",
        verifyFlags: "CONST_SCRIPTCODE,LOW_S"
    ),

    // CODESEPARATOR in an unexecuted IF block does not change what is hashed
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "a955032f4d6b0c9bfe8cad8f00a8933790b9c1dc28c82e0f48e75b35da0e4944",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .if,
                    .codeSeparator,
                    .endIf,
                    .pushBytes(.init(hex: "0378d430274f8c5ec1321338151e9f27f4c676a008bdf8638d07c0b6be9ab35c71")!),
                    .checkSigVerify,
                    .codeSeparator,
                    .constant(1)
                ]
            ),
        ],
        serializedTransaction: "010000000144490eda355be7480f2ec828dcc1b9903793a8008fad8cfe9b0c6b4d2f0355a9000000004a48304502207a6974a77c591fa13dff60cabbb85a0de9e025c09c65a4b2285e47ce8e22f761022100f0efaac9ff8ac36b10721e0aae1fb975c90500b50c56e8a0cc52b0403f0425dd0100ffffffff010000000000000000016a00000000",
        verifyFlags: "CONST_SCRIPTCODE,LOW_S"
    ),

    // As above, with the IF block executed
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "a955032f4d6b0c9bfe8cad8f00a8933790b9c1dc28c82e0f48e75b35da0e4944",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .if,
                    .codeSeparator,
                    .endIf,
                    .pushBytes(.init(hex: "0378d430274f8c5ec1321338151e9f27f4c676a008bdf8638d07c0b6be9ab35c71")!),
                    .checkSigVerify,
                    .codeSeparator,
                    .constant(1)
                ]
            ),
        ],
        serializedTransaction: "010000000144490eda355be7480f2ec828dcc1b9903793a8008fad8cfe9b0c6b4d2f0355a9000000004a483045022100fa4a74ba9fd59c59f46c3960cf90cbe0d2b743c471d24a3d5d6db6002af5eebb02204d70ec490fd0f7055a7c45f86514336e3a7f03503dacecabb247fc23f15c83510151ffffffff010000000000000000016a00000000",
        verifyFlags: "CONST_SCRIPTCODE"
    ),

    // CHECKSIG is legal in scriptSigs
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "ccf7f4053a02e653c36ac75c891b7496d0dc5ce5214f6c913d9cf8f1329ebee0",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "ee5a6aa40facefb2655ac23c0c28c57c65c41f9b")!),
                    .equalVerify,
                    .checkSig
                ]
            ),
        ],
        serializedTransaction: "0100000001e0be9e32f1f89c3d916c4f21e55cdcd096741b895cc76ac353e6023a05f4f7cc00000000d86149304602210086e5f736a2c3622ebb62bd9d93d8e5d76508b98be922b97160edc3dcca6d8c47022100b23c312ac232a4473f19d2aeb95ab7bdf2b65518911a0d72d50e38b5dd31dc820121038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f22041ac4730440220508fa761865c8abd81244a168392876ee1d94e8ed83897066b5e2df2400dad24022043f5ee7538e87e9c6aef7ef55133d3e51da7cc522830a9c4d736977a76ef755c0121038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f22041ffffffff010000000000000000016a00000000",
        verifyFlags: "SIGPUSHONLY,CONST_SCRIPTCODE,LOW_S,CLEANSTACK"
    ),

    // Same semantics for OP_CODESEPARATOR
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "10c9f0effe83e97f80f067de2b11c6a00c3088a4bce42c5ae761519af9306f3c",
                outputIndex: 1,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "ee5a6aa40facefb2655ac23c0c28c57c65c41f9b")!),
                    .equalVerify,
                    .checkSig
                ]
            ),
        ],
        serializedTransaction: "01000000013c6f30f99a5161e75a2ce4bca488300ca0c6112bde67f0807fe983feeff0c91001000000e608646561646265656675ab61493046022100ce18d384221a731c993939015e3d1bcebafb16e8c0b5b5d14097ec8177ae6f28022100bcab227af90bab33c3fe0a9abfee03ba976ee25dc6ce542526e9b2e56e14b7f10121038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f22041ac493046022100c3b93edcc0fd6250eb32f2dd8a0bba1754b0f6c3be8ed4100ed582f3db73eba2022100bf75b5bd2eff4d6bf2bda2e34a40fcc07d4aa3cf862ceaa77b47b81eff829f9a01ab21038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f22041ffffffff010000000000000000016a00000000",
        verifyFlags: "SIGPUSHONLY,CONST_SCRIPTCODE,LOW_S,CLEANSTACK"
    ),

    // Signatures are removed from the script they are in by FindAndDelete() in the CHECKSIG code; even multiple instances of one signature can be removed.
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "6056ebd549003b10cbbd915cea0d82209fe40b8617104be917a26fa92cbe3d6f",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "ee5a6aa40facefb2655ac23c0c28c57c65c41f9b")!),
                    .equalVerify,
                    .checkSig
                ]
            ),
        ],
        serializedTransaction: "01000000016f3dbe2ca96fa217e94b1017860be49f20820dea5c91bdcb103b0049d5eb566000000000fd1d0147304402203989ac8f9ad36b5d0919d97fa0a7f70c5272abee3b14477dc646288a8b976df5022027d19da84a066af9053ad3d1d7459d171b7e3a80bc6c4ef7a330677a6be548140147304402203989ac8f9ad36b5d0919d97fa0a7f70c5272abee3b14477dc646288a8b976df5022027d19da84a066af9053ad3d1d7459d171b7e3a80bc6c4ef7a330677a6be548140121038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f22041ac47304402203757e937ba807e4a5da8534c17f9d121176056406a6465054bdd260457515c1a02200f02eccf1bec0f3a0d65df37889143c2e88ab7acec61a7b6f5aa264139141a2b0121038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f22041ffffffff010000000000000000016a00000000",
        verifyFlags: "SIGPUSHONLY,CONST_SCRIPTCODE,CLEANSTACK"
    ),

    // That also includes ahead of the opcode being executed.
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "5a6b0021a6042a686b6b94abc36b387bef9109847774e8b1e51eb8cc55c53921",
                outputIndex: 1,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "ee5a6aa40facefb2655ac23c0c28c57c65c41f9b")!),
                    .equalVerify,
                    .checkSig
                ]
            ),
        ],
        serializedTransaction: "01000000012139c555ccb81ee5b1e87477840991ef7b386bc3ab946b6b682a04a621006b5a01000000fdb40148304502201723e692e5f409a7151db386291b63524c5eb2030df652b1f53022fd8207349f022100b90d9bbf2f3366ce176e5e780a00433da67d9e5c79312c6388312a296a5800390148304502201723e692e5f409a7151db386291b63524c5eb2030df652b1f53022fd8207349f022100b90d9bbf2f3366ce176e5e780a00433da67d9e5c79312c6388312a296a5800390121038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f2204148304502201723e692e5f409a7151db386291b63524c5eb2030df652b1f53022fd8207349f022100b90d9bbf2f3366ce176e5e780a00433da67d9e5c79312c6388312a296a5800390175ac4830450220646b72c35beeec51f4d5bc1cbae01863825750d7f490864af354e6ea4f625e9c022100f04b98432df3a9641719dbced53393022e7249fb59db993af1118539830aab870148304502201723e692e5f409a7151db386291b63524c5eb2030df652b1f53022fd8207349f022100b90d9bbf2f3366ce176e5e780a00433da67d9e5c79312c6388312a296a580039017521038479a0fa998cd35259a2ef0a7a5c68662c1474f88ccb6d08a7677bbec7f22041ffffffff010000000000000000016a00000000",
        verifyFlags: "SIGPUSHONLY,CONST_SCRIPTCODE,LOW_S,CLEANSTACK"
    ),

    // Finally CHECKMULTISIG removes all signatures prior to hashing the script containing those signatures. In conjunction with the SIGHASH_SINGLE bug this lets us test whether or not FindAndDelete() is actually present in scriptPubKey/redeemScript evaluation by including a signature of the digest 0x01 We can compute in advance for our pubkey, embed it in the scriptPubKey, and then also using a normal SIGHASH_ALL signature. If FindAndDelete() wasn't run, the 'bugged' signature would still be in the hashed script, and the normal signature would fail.
    // Here's an example on mainnet within a P2SH redeemScript. Remarkably it's a standard transaction in <0.9
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "b5b598de91787439afd5938116654e0b16b7a0d0f82742ba37564219c5afcbf9",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "f6f365c40f0739b61de827a44751e5e99032ed8f")!),
                    .equalVerify,
                    .checkSig
                ]
            ),
            .init(
                transactionIdentifier: "ab9805c6d57d7070d9a42c5176e47bb705023e6b67249fb6760880548298e742",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .hash160,
                    .pushBytes(.init(hex: "d8dacdadb7462ae15cd906f1878706d0da8660e6")!),
                    .equal
                ]
            ),
        ],
        serializedTransaction: "0100000002f9cbafc519425637ba4227f8d0a0b7160b4e65168193d5af39747891de98b5b5000000006b4830450221008dd619c563e527c47d9bd53534a770b102e40faa87f61433580e04e271ef2f960220029886434e18122b53d5decd25f1f4acb2480659fea20aabd856987ba3c3907e0121022b78b756e2258af13779c1a1f37ea6800259716ca4b7f0b87610e0bf3ab52a01ffffffff42e7988254800876b69f24676b3e0205b77be476512ca4d970707dd5c60598ab00000000fd260100483045022015bd0139bcccf990a6af6ec5c1c52ed8222e03a0d51c334df139968525d2fcd20221009f9efe325476eb64c3958e4713e9eefe49bf1d820ed58d2112721b134e2a1a53034930460221008431bdfa72bc67f9d41fe72e94c88fb8f359ffa30b33c72c121c5a877d922e1002210089ef5fc22dd8bfc6bf9ffdb01a9862d27687d424d1fefbab9e9c7176844a187a014c9052483045022015bd0139bcccf990a6af6ec5c1c52ed8222e03a0d51c334df139968525d2fcd20221009f9efe325476eb64c3958e4713e9eefe49bf1d820ed58d2112721b134e2a1a5303210378d430274f8c5ec1321338151e9f27f4c676a008bdf8638d07c0b6be9ab35c71210378d430274f8c5ec1321338151e9f27f4c676a008bdf8638d07c0b6be9ab35c7153aeffffffff01a08601000000000017a914d8dacdadb7462ae15cd906f1878706d0da8660e68700000000",
        verifyFlags: "CONST_SCRIPTCODE,LOW_S"
    ),

    // Same idea, but with bare CHECKMULTISIG
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "ceafe58e0f6e7d67c0409fbbf673c84c166e3c5d3c24af58f7175b18df3bb3db",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "f6f365c40f0739b61de827a44751e5e99032ed8f")!),
                    .equalVerify,
                    .checkSig
                ]
            ),
            .init(
                transactionIdentifier: "ceafe58e0f6e7d67c0409fbbf673c84c166e3c5d3c24af58f7175b18df3bb3db",
                outputIndex: 1,
                amount: 0,
                scriptOperations: [
                    .constant(2),
                    .pushBytes(.init(hex: "3045022015bd0139bcccf990a6af6ec5c1c52ed8222e03a0d51c334df139968525d2fcd20221009f9efe325476eb64c3958e4713e9eefe49bf1d820ed58d2112721b134e2a1a5303")!),
                    .pushBytes(.init(hex: "0378d430274f8c5ec1321338151e9f27f4c676a008bdf8638d07c0b6be9ab35c71")!),
                    .pushBytes(.init(hex: "0378d430274f8c5ec1321338151e9f27f4c676a008bdf8638d07c0b6be9ab35c71")!),
                    .constant(3),
                    .checkMultiSig
                ]
            ),
        ],
        serializedTransaction: "0100000002dbb33bdf185b17f758af243c5d3c6e164cc873f6bb9f40c0677d6e0f8ee5afce000000006b4830450221009627444320dc5ef8d7f68f35010b4c050a6ed0d96b67a84db99fda9c9de58b1e02203e4b4aaa019e012e65d69b487fdf8719df72f488fa91506a80c49a33929f1fd50121022b78b756e2258af13779c1a1f37ea6800259716ca4b7f0b87610e0bf3ab52a01ffffffffdbb33bdf185b17f758af243c5d3c6e164cc873f6bb9f40c0677d6e0f8ee5afce010000009300483045022015bd0139bcccf990a6af6ec5c1c52ed8222e03a0d51c334df139968525d2fcd20221009f9efe325476eb64c3958e4713e9eefe49bf1d820ed58d2112721b134e2a1a5303483045022015bd0139bcccf990a6af6ec5c1c52ed8222e03a0d51c334df139968525d2fcd20221009f9efe325476eb64c3958e4713e9eefe49bf1d820ed58d2112721b134e2a1a5303ffffffff01a0860100000000001976a9149bc0bbdd3024da4d0c38ed1aecf5c68dd1d3fa1288ac00000000",
        verifyFlags: "CONST_SCRIPTCODE,LOW_S"
    ),

    // MARK: - CHECKLOCKTIMEVERIFY tests (BIP65)

    // By-height locks, with argument == 0 and == tx nLockTime
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .zero,
                    .checkLockTimeVerify,
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "010000000100010000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000",
        verifyFlags: "CLEANSTACK"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "1dcd64ff")!.reversed())), // 499_999_999
                    .checkLockTimeVerify
                ]
            )
        ],
        serializedTransaction: "0100000001000100000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000ff64cd1d",
        verifyFlags: "NONE"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .zero,
                    .checkLockTimeVerify,
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "0100000001000100000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000ff64cd1d",
        verifyFlags: "CLEANSTACK"
    ),

    // By-time locks, with argument just beyond tx nLockTime (but within numerical boundaries)
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "1dcd6500")!.reversed())), // 500_000_000
                    .checkLockTimeVerify,
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000065cd1d",
        verifyFlags: "NONE"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "00ffffffff")!.reversed())), // 4_294_967_295
                    .checkLockTimeVerify
                ]
            )
        ],
        serializedTransaction: "0100000001000100000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000ffffffff",
        verifyFlags: "NONE"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "1dcd6500")!.reversed())), // 500_000_000
                    .checkLockTimeVerify
                ]
            )
        ],
        serializedTransaction: "0100000001000100000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000ffffffff",
        verifyFlags: "NONE"
    ),

    // Any non-maxint nSequence is fine
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .zero,
                    .checkLockTimeVerify,
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "010000000100010000000000000000000000000000000000000000000000000000000000000000000000feffffff0100000000000000000000000000",
        verifyFlags: "CLEANSTACK"
    ),

    // The argument can be calculated rather than created directly by a PUSHDATA
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "1dcd64ff")!.reversed())), // 499_999_999
                    .oneAdd,
                    .checkLockTimeVerify
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000065cd1d",
        verifyFlags: "NONE"
    ),

    // Perhaps even by an ADD producing a 5-byte result that is out of bounds for other opcodes
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "7fffffff")!.reversed())), // 2_147_483_647
                    .pushBytes(.init(Data(hex: "7fffffff")!.reversed())), // 2_147_483_647
                    .add,
                    .checkLockTimeVerify
                ]
            )
        ],
        serializedTransaction: "0100000001000100000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000feffffff",
        verifyFlags: "NONE"
    ),

    // 5 byte non-minimally-encoded arguments are valid
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(hex: "0000000000")!),
                    .checkLockTimeVerify,
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "010000000100010000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000",
        verifyFlags: "CLEANSTACK,MINIMALDATA"
    ),

    // Valid CHECKLOCKTIMEVERIFY in scriptSig
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "01000000010001000000000000000000000000000000000000000000000000000000000000000000000251b1000000000100000000000000000001000000",
        verifyFlags: "SIGPUSHONLY,CLEANSTACK"
    ),

    // Valid CHECKLOCKTIMEVERIFY in redeemScript
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .hash160,
                    .pushBytes(.init(hex: "c5b93064159b3b2d6ab506a41b1f50463771b988")!),
                    .equal
                ]
            )
        ],
        serializedTransaction: "0100000001000100000000000000000000000000000000000000000000000000000000000000000000030251b1000000000100000000000000000001000000",
        verifyFlags: "NONE"
    ),

    // A transaction with a non-standard DER signature.
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "b1dbc81696c8a9c0fccd0693ab66d7c368dbc38c0def4e800685560ddd1b2132",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .dup,
                    .hash160,
                    .pushBytes(.init(hex: "4b3bd7eba3bc0284fd3007be7f3be275e94f5826")!),
                    .equalVerify,
                    .checkSig
                ]
            )
        ],
        serializedTransaction: "010000000132211bdd0d568506804eef0d8cc3db68c3d766ab9306cdfcc0a9c89616c8dbb1000000006c493045022100c7bb0faea0522e74ff220c20c022d2cb6033f8d167fb89e75a50e237a35fd6d202203064713491b1f8ad5f79e623d0219ad32510bfaa1009ab30cbee77b59317d6e30001210237af13eb2d84e4545af287b919c2282019c9691cc509e78e196a9d8274ed1be0ffffffff0100000000000000001976a914f1b3ed2eda9a2ebe5a9374f692877cdf87c0f95b88ac00000000",
        verifyFlags: "DERSIG,LOW_S,STRICTENC"
    ),

    // MARK: - CHECKSEQUENCEVERIFY tests

    // By-height locks, with argument == 0 and == txin.nSequence
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .zero,
                    .checkSequenceVerify,
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000",
        verifyFlags: "CLEANSTACK"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "00ffff")!.reversed())), // 65_535
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000ffff00000100000000000000000000000000",
        verifyFlags: "NONE"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "00ffff")!.reversed())), // 65_535
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000ffffbf7f0100000000000000000000000000",
        verifyFlags: "NONE"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .zero,
                    .checkSequenceVerify,
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000ffffbf7f0100000000000000000000000000",
        verifyFlags: "CLEANSTACK"
    ),

    // By-time locks, with argument == 0 and == txin.nSequence
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "400000")!.reversed())), // 4_194_304
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000000040000100000000000000000000000000",
        verifyFlags: "NONE"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "40ffff")!.reversed())), // 4_259_839
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000ffff40000100000000000000000000000000",
        verifyFlags: "NONE"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "40ffff")!.reversed())), // 4_259_839
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000ffffff7f0100000000000000000000000000",
        verifyFlags: "NONE"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "400000")!.reversed())), // 4_194_304
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000ffffff7f0100000000000000000000000000",
        verifyFlags: "NONE"
    ),

    // Upper sequence with upper sequence is fine
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "0080000000")!.reversed())), // 2_147_483_648
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000000000800100000000000000000000000000",
        verifyFlags: "NONE"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "00ffffffff")!.reversed())), // 4_294_967_295
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000000000800100000000000000000000000000",
        verifyFlags: "NONE"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "0080000000")!.reversed())), // 2_147_483_648
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000feffffff0100000000000000000000000000",
        verifyFlags: "NONE"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "00ffffffff")!.reversed())), // 4_294_967_295
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000feffffff0100000000000000000000000000",
        verifyFlags: "NONE"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "0080000000")!.reversed())), // 2_147_483_648
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000ffffffff0100000000000000000000000000",
        verifyFlags: "NONE"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "00ffffffff")!.reversed())), // 4_294_967_295
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000ffffffff0100000000000000000000000000",
        verifyFlags: "NONE"
    ),

    // Argument 2^31 with various nSequence
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "0080000000")!.reversed())), // 2_147_483_648
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000ffffbf7f0100000000000000000000000000",
        verifyFlags: "NONE"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "0080000000")!.reversed())), // 2_147_483_648
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000ffffff7f0100000000000000000000000000",
        verifyFlags: "NONE"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "0080000000")!.reversed())), // 2_147_483_648
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000ffffffff0100000000000000000000000000",
        verifyFlags: "NONE"
    ),

    // Argument 2^32-1 with various nSequence

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "00ffffffff")!.reversed())), // 4_294_967_295
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000ffffbf7f0100000000000000000000000000",
        verifyFlags: "NONE"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "00ffffffff")!.reversed())), // 4_294_967_295
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000ffffff7f0100000000000000000000000000",
        verifyFlags: "NONE"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "00ffffffff")!.reversed())), // 4_294_967_295
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000ffffffff0100000000000000000000000000",
        verifyFlags: "NONE"
    ),

    // Argument 3<<31 with various nSequence

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(hex: "0000008001")!),
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000ffffbf7f0100000000000000000000000000",
        verifyFlags: "NONE"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(hex: "0000008001")!),
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000ffffff7f0100000000000000000000000000",
        verifyFlags: "NONE"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(hex: "0000008001")!),
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000ffffffff0100000000000000000000000000",
        verifyFlags: "NONE"
    ),

    // 5 byte non-minimally-encoded operandss are valid
    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(hex: "0000000000")!),
                    .checkSequenceVerify,
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000",
        verifyFlags: "MINIMALDATA,CLEANSTACK"
    ),

    // The argument can be calculated rather than created directly by a PUSHDATA

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "3ffffff")!.reversed())), // 4_194_303
                    .oneAdd,
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000000040000100000000000000000000000000",
        verifyFlags: "NONE"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "0x400000")!.reversed())), // 4_194_304
                    .oneSub,
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000ffff00000100000000000000000000000000",
        verifyFlags: "NONE"
    ),

    // An ADD producing a 5-byte result that sets CTxIn::SEQUENCE_LOCKTIME_DISABLE_FLAG"

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "7fffffff")!.reversed())), // 2_147_483_647
                    .pushBytes(.init(Data(hex: "10000")!.reversed())), // 65_536
                    .add,
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000",
        verifyFlags: "NONE"
    ),

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .pushBytes(.init(Data(hex: "7fffffff")!.reversed())), // 2_147_483_647
                    .pushBytes(.init(Data(hex: "410000")!.reversed())), // 4_259_840
                    .add,
                    .checkSequenceVerify
                ]
            )
        ],
        serializedTransaction: "020000000100010000000000000000000000000000000000000000000000000000000000000000000000000040000100000000000000000000000000",
        verifyFlags: "NONE"
    ),

    // Valid CHECKSEQUENCEVERIFY in scriptSig

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .constant(1)
                ]
            )
        ],
        serializedTransaction: "02000000010001000000000000000000000000000000000000000000000000000000000000000000000251b2010000000100000000000000000000000000",
        verifyFlags: "SIGPUSHONLY,CLEANSTACK"
    ),

    // Valid CHECKSEQUENCEVERIFY in redeemScript

    .init(
        previousOutputs: [
            .init(
                transactionIdentifier: "0000000000000000000000000000000000000000000000000000000000000100",
                outputIndex: 0,
                amount: 0,
                scriptOperations: [
                    .hash160,
                    .pushBytes(.init(hex: "7c17aff532f22beb54069942f9bf567a66133eaf")!),
                    .equal
                ]
            )
        ],
        serializedTransaction: "0200000001000100000000000000000000000000000000000000000000000000000000000000000000030251b2010000000100000000000000000000000000",
        verifyFlags: "NONE"
    ),
]