import Testing
import Foundation
import BitcoinCrypto
import BitcoinBase
import BitcoinBlockchain
import BitcoinWallet

struct BlockchainIntegrationTests {

    /// Checks that some of the newly learned block's transaction might already be in our mempool.
    @Test("New block transaction already in mempool")
    func blockTxInMempool() async throws {
        let aliceKey = SecretKey()
        let alicePK = aliceKey.pubkey
        let bobKey = SecretKey()
        let bobPK = bobKey.pubkey
        let carolKey = SecretKey()
        let carolPK = carolKey.pubkey
        let derekKey = SecretKey()
        let derekPK = derekKey.pubkey
        let errolKey = SecretKey()
        let errolPK = errolKey.pubkey
        let fionaKey = SecretKey()
        let fionaPK = fionaKey.pubkey
        let gabrielKey = SecretKey()
        let gabrielPK = gabrielKey.pubkey

        let alice = BlockchainService()
        let bob = BlockchainService()

        let genesisBlock = await alice.blocks[0]
        #expect(await bob.blocks[0] == genesisBlock)

        // Mine 100 blocks so block 1's coinbase output reaches maturity.
        for _ in 0 ..< 100 {
            await alice.generateTo(alicePK)
        }
        #expect(await alice.tip == 101)

        for i in 1 ..< 101 {
            try await bob.processBlock(await alice.blocks[i])
        }
        #expect(await bob.tip == 101)

        // Grab block 1's coinbase transaction and output.
        let coinbaseTx = await alice.getBlock(1).txs[0]

        var t_a3 = BitcoinTx(
            ins: [.init(outpoint: coinbaseTx.outpoint(0))],
            outs: [
                .init(value: 10, script: .payToPubkeyHash(bobPK)),
                .init(value: 15, script: .payToPubkeyHash(carolPK)),
                .init(value: 20, script: .payToPubkeyHash(derekPK))
            ])

        var signer = TxSigner(tx: t_a3, prevouts: [coinbaseTx.outs[0]])
        signer.sign(txIn: 0, with: aliceKey)
        t_a3 = signer.tx

        #expect(await alice.mempool.count == 0)
        try #require(await alice.addTx(t_a3))
        #expect(await alice.mempool.count == 1)

        #expect(await bob.mempool.count == 0)
        try #require(await bob.addTx(t_a3))
        #expect(await bob.mempool.count == 1)

        await alice.generateTo(alicePK)
        #expect(await alice.mempool.count == 0)

        #expect(await bob.blocks.count == 101)
        try await bob.processBlock(await alice.blocks.last!)
        #expect(await bob.blocks.count == 102)
        #expect(await bob.mempool.count == 0)

        var tA1_b2 = BitcoinTx(
            ins: [.init(outpoint: t_a3.outpoint(1))],
            outs: [
                .init(value: 10, script: .payToPubkeyHash(derekPK)),
                .init(value: 5, script: .payToPubkeyHash(errolPK))
            ])
        signer = TxSigner(tx: tA1_b2, prevouts: [t_a3.outs[1]])
        signer.sign(txIn: 0, with: carolKey)
        tA1_b2 = signer.tx

        var tA0_A2_c2 = BitcoinTx(
            ins: [
                .init(outpoint: t_a3.outpoint(0)),
                .init(outpoint: t_a3.outpoint(2))
            ],
            outs: [
                .init(value: 15, script: .payToPubkeyHash(fionaPK)),
                .init(value: 15, script: .payToPubkeyHash(gabrielPK))
            ])
        signer = TxSigner(tx: tA0_A2_c2, prevouts: [t_a3.outs[0], t_a3.outs[2]])
        signer.sign(txIn: 0, with: bobKey)
        signer.sign(txIn: 1, with: derekKey)
        tA0_A2_c2 = signer.tx

        try #require(await bob.addTx(tA1_b2))
        #expect(await bob.mempool.count == 1)

        try #require(await bob.addTx(tA0_A2_c2))
        #expect(await bob.mempool.count == 2)

        try #require(await alice.addTx(tA0_A2_c2))
        #expect(await alice.mempool.count == 1)


        await bob.generateTo(bobPK)
        #expect(await bob.mempool.isEmpty)
        #expect(await bob.blocks.last!.txs[2] == tA0_A2_c2)
        #expect(await bob.blocks.count == 103)

        try await alice.processBlock(await bob.blocks.last!)
        #expect(await alice.mempool.isEmpty)
    }
}
