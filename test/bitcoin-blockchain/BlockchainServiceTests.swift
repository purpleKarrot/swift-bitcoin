import Testing
import Foundation
@testable import BitcoinBlockchain // @testable for sigHash(), SigHashType
import BitcoinCrypto
import BitcoinBase

struct BlockchainServiceTests {

    /// Tests synchronizing blocks between two blockchains.
    @Test("Dual blockchain synchronization")
    func dualBlockchainSync() async throws {
        let secretKey = SecretKey()
        let pubkey = secretKey.pubkey

        let alice = BlockchainService()
        await alice.generateTo(pubkey)

        let bob = BlockchainService()

        let header1 = await alice.blocks[1]

        try await bob.processHeaders([header1])
        await #expect(bob.blocks.count == 2)

        let bobMissingBlockIDs = await bob.getNextMissingBlocks(.max)
        #expect(bobMissingBlockIDs == [header1.id])

        let bobMissingBlocks = await alice.getBlocks(bobMissingBlockIDs)
        let bobMissingBlock = bobMissingBlocks[0]
        let block1 = await alice.getBlock(1)
        #expect(bobMissingBlocks.count == 1 && bobMissingBlock == header1 && bobMissingBlock.txs == block1.txs)

        await bob.processBlock(block1)
        await #expect(bob.tip == 2)
    }

    /// Tests synchronizing blocks between two blockchains.
    @Test("Blockchain synchronization with traffic limit")
    func tafficLimitBlockchainSync() async throws {
        let secretKey = SecretKey()
        let pubkey = secretKey.pubkey

        let alice = BlockchainService()

        let bob = BlockchainService()
        await bob.generateTo(pubkey)
        await bob.generateTo(pubkey)
        await bob.generateTo(pubkey)

        let aliceLocator = await alice.makeBlockLocator()
        #expect(aliceLocator.count == 1)

        let bobHeaders = await bob.findHeaders(using: aliceLocator)
        #expect(bobHeaders.count == 3)

        try await alice.processHeaders(bobHeaders)
        await #expect(alice.blocks.count == 4)
        await #expect(alice.tip == 1)

        let aliceMissing = await alice.getNextMissingBlocks(2)
        #expect(aliceMissing.count == 2)

        let bobBlocks1to2 = await bob.getBlocks(aliceMissing)
        #expect(bobBlocks1to2.count == 2)

        await alice.processBlock(bobBlocks1to2[0])
        await #expect(alice.blocks.count == 4)
        await #expect(alice.tip == 2)

        await alice.processBlock(bobBlocks1to2[1])
        await #expect(alice.blocks.count == 4)
        await #expect(alice.tip == 3)

        let aliceMissing2 = await alice.getNextMissingBlocks(2)
        #expect(aliceMissing2.count == 1)

        let bobBlocks3to3 = await bob.getBlocks(aliceMissing2)
        #expect(bobBlocks3to3.count == 1)

        await alice.processBlock(bobBlocks3to3[0])
        await #expect(alice.blocks.count == 4)
        await #expect(alice.tip == 4)
    }


    /// Tests mining empty blocks, spending a coinbase transaction and mine again.
    @Test("Mine and spend")
    func mineAndSpend() async throws {

        // Generate a secret key, corresponding public key, hash and address.
        let secretKey = SecretKey()
        let pubkey = secretKey.pubkey

        // Instantiate a fresh Bitcoin service (regtest).
        let service = BlockchainService()

        // Create the genesis block.
        await service.createGenesisBlock()

        // Mine 100 blocks so block 1's coinbase output reaches maturity.
        for _ in 0 ..< 100 {
            await service.generateTo(pubkey)
        }

        // Grab block 1's coinbase transaction and output.
        let previousTx = await service.getBlock(1).txs[0]
        let prevout = previousTx.outs[0]

        // Create a new transaction spending from the previous transaction's outpoint.
        let unsignedInput = TxIn(outpoint: previousTx.outpoint(0))

        // Specify the transaction's output. We'll leave 1000 sats on the table to tip miners. We'll re-use the origin address for simplicity.
        let unsignedTx = BitcoinTx(
            ins: [unsignedInput],
            outs: [
                .init(value: 49_99_999_000, script: .payToPubkeyHash(pubkey))
            ])

        // Sign the transaction by first calculating the signature hash.
        let sighash = SigHash(tx: unsignedTx, txIn: 0, prevout: prevout).value

        // Obtain the signature using our secret key and append the signature hash type.
        let sig = AnySig(hash: sighash, secretKey: secretKey)
        let sigData = ExtendedSig(sig, .all).data

        // Sign our input by including the signature and public key.
        let signedInput = TxIn(
            outpoint: unsignedInput.outpoint,
            sequence: unsignedInput.sequence,
            script: .init([
                .pushBytes(sigData),
                .pushBytes(pubkey.data)
            ]),
            witness: unsignedInput.witness)

        // Put the signed input back into the transaction.
        let signedTx = BitcoinTx(
            version: unsignedTx.version,
            locktime: unsignedTx.locktime,
            ins: [signedInput],
            outs: unsignedTx.outs)

        // Make sure the transaction was signed correctly by verifying the scripts.
        #expect(signedTx.verifyScript(prevouts: [prevout]))

        // Submit the signed transaction to the mempool.
        try await service.addTx(signedTx)
        let mempoolBefore = await service.mempool.count
        #expect(mempoolBefore == 1)

        // Let's mine another block to confirm our transaction.
        await service.generateTo(pubkey)
        let mempoolAfter = await service.mempool.count

        // Verify the mempool is empty once again.
        #expect(mempoolAfter == 0)
        let blocks = await service.tip
        #expect(blocks == 102)
        let lastBlockTxs = try #require(await service.blocks.last!.txs)
        // Verify our transaction was confirmed in a block.
        #expect(lastBlockTxs[1] == signedTx)
    }

    @Test("Difficulty Target")
    func difficultyTarget() async throws {
        let difficultyBits = 0x207fffff
        let powLimitBE = Data([0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]) // Regtest
        let powLimitLE = Data(powLimitBE.reversed())
        let powLimitTarget = DifficultyTarget(powLimitLE)
        #expect(powLimitTarget.data == powLimitLE)
        let powLimitCompact = powLimitTarget.toCompact()
        #expect(powLimitCompact == difficultyBits)

        var neg: Bool = true
        var over: Bool = true
        let powLimitTarget_ = DifficultyTarget(compact: powLimitCompact, negative: &neg, overflow: &over)
        #expect(!powLimitTarget_.isZero && !neg && !over)
        let powLimitLE_ = powLimitTarget_.data
        #expect(powLimitLE_.reversed().hex == "7fffff0000000000000000000000000000000000000000000000000000000000")
    }

    @Test("Difficulty Adjustment")
    func difficultyAdjustment() async throws {
        let service = BlockchainService(consensusParams: .init(
            powLimit: Data([0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
            powTargetTimespan: 1 * 1 * 10 * 60, // 12 minutes
            powTargetSpacing: 2 * 60, // 2 minutes
            powAllowMinDifficultyBlocks: true,
            powNoRetargeting: false,
            genesisBlockTime: 1296688602,
            genesisBlockNonce: 2,
            genesisBlockTarget: 0x207fffff
        ))
        await service.createGenesisBlock()
        let genesisBlock = await service.genesisBlock

        #expect(genesisBlock.target == 0x207fffff)
        let genesisDate = genesisBlock.time
        var date = genesisDate
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .gmt

        let pubkey = try #require(PubKey(compressed: [0x03, 0x5a, 0xc9, 0xd1, 0x48, 0x78, 0x68, 0xec, 0xa6, 0x4e, 0x93, 0x2a, 0x06, 0xee, 0x8d, 0x6d, 0x2e, 0x89, 0xd9, 0x86, 0x59, 0xdb, 0x7f, 0x24, 0x74, 0x10, 0xd3, 0xe7, 0x9f, 0x88, 0xf8, 0xd0, 0x05])) // Testnet p2pkh address  miueyHbQ33FDcjCYZpVJdC7VBbaVQzAUg5
        for i in 1...15 {
            let minutes = if i < 5 { 4 } else if i < 10 { 2 } else { 4 }
            date = calendar.date(byAdding: .minute, value: minutes, to: date)!
            await service.generateTo(pubkey, blockTime: date)
            let header = await service.blocks.last!
            let expectedTarget = if (1...4).contains(i) {
                0x207fffff // 0x7fffff0000000000000000000000000000000000000000000000000000000000 DifficultyTarget(compact: block.target).data.reversed().hex
            } else if (5...9).contains(i) {
                0x1f6d386d // 0x006d386d00000000000000000000000000000000000000000000000000000000
            } else if (10...14).contains(i) {
                0x1f576057 // 0x0057605700000000000000000000000000000000000000000000000000000000
            } else {
                0x1f1e9351 // 0x001e935100000000000000000000000000000000000000000000000000000000
            }
            #expect(header.target == expectedTarget)
        }
    }

    @Test("Difficulty", arguments: [
        // very_low_target
        (0x1f111111, 0.000001),
        // low_target
        (0x1ef88f6f, 0.000016),
        // mid_target
        (0x1df88f6f, 0.004023),
        // high_target
        (0x1cf88f6f, 1.029916),
        // very_high_target
        (0x12345678, 5913134931067755359633408.0)
    ])
    func difficulty(compact: Int, expected: Double) async throws {
        var negative = true
        var overflow = true
        let target = DifficultyTarget(compact: compact, negative: &negative, overflow: &overflow)
        #expect(!target.isZero)
        #expect(!overflow)
        #expect(target.toCompact(negative: negative) == compact)
        #expect(isApproximatelyEqual(DifficultyTarget.getDifficulty(compact), to: expected, absoluteTolerance: 0.00001))
    }
}

fileprivate func isApproximatelyEqual(
    _ value: Double,
    to other: Double,
    absoluteTolerance: Double,
    relativeTolerance: Double = 0
  ) -> Bool {
    precondition(
      absoluteTolerance >= 0 && absoluteTolerance.isFinite,
      "absoluteTolerance should be non-negative and finite, " +
      "but is \(absoluteTolerance)."
    )
    precondition(
      relativeTolerance >= 0 && relativeTolerance <= 1,
      "relativeTolerance should be non-negative and <= 1, " +
      "but is \(relativeTolerance)."
    )
    if value == other { return true }
    let delta = value - other
    let scale = max(value, other)
    let bound = max(absoluteTolerance, scale*relativeTolerance)
    return delta.isFinite && delta <= bound
}
