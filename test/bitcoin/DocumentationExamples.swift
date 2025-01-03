import Foundation
import Testing
import Bitcoin

struct DocumentationExamples {

    @Test func gettingStarted() async throws {
        // Generate a secret key, corresponding public key, hash and address.
        let secretKey = SecretKey()
        let pubkey = secretKey.pubkey
        let address = LegacyAddress(pubkey)

        // # Prepare the Blockchain service.

        // Create a fresh blockchain service instance (on regtest).
        let blockchain = BlockchainService()

        // Mine 100 blocks so block 1's coinbase output reaches maturity.
        for _ in 0 ..< 100 {
            await blockchain.generateTo(pubkey)
        }

        // # Prepare our transaction.

        // Grab block 1's coinbase transaction and output.
        let fundingTx = await blockchain.blocks[1].txs[0]
        let prevout = fundingTx.outs[0]

        // Create a new transaction spending from the previous transaction's outpoint.
        let unsignedInput = TxIn(outpoint: fundingTx.outpoint(0))

        // Specify the transaction's output. We'll leave 1000 sats on the table to tip miners. We'll re-use the origin address for simplicity.
        let spendingTx = BitcoinTx(ins: [unsignedInput], outs: [address.out(100)])

        // # We now need to sign the transaction using our secret key.

        let signer = TxSigner(tx: spendingTx, prevouts: [prevout])
        let signedTx = signer.sign(txIn: 0, with: secretKey)

        // # We can verify that the transaction was signed correctly.

        // Make sure the transaction was signed correctly by verifying the scripts.
        let isVerified = signedTx.verifyScript(prevouts: [prevout])

        #expect(isVerified)
        // Yay! Our transaction is valid.

        // # Now we're ready to submit our signed transaction to the mempool.

        // Submit the signed transaction to the mempool.
        try await blockchain.addTx(signedTx)

        // The mempool should now contain our transaction.
        #expect(await blockchain.mempool.count == 1)

        // # After confirming the transaction was accepted we can mine a block and get it confirmed.

        // Let's mine another block to confirm our transaction.

        // In this case we can re-use the address we created before.
        let pubkeyHash = Data(Hash160.hash(data: pubkey.data))

        // Minde to the public key hash
        await blockchain.generateTo(pubkeyHash)

        // The mempool should now be empty.
        #expect(await blockchain.mempool.count == 0)

        // # Finally let's make sure the transaction was confirmed in a block.

        let blocks = await blockchain.blocks.count
        #expect(blocks == 102)

        let lastBlock = await blockchain.blocks.last!
        // Verify our transaction was confirmed in a block.

        #expect(lastBlock.txs[1] == signedTx)
        // Our transaction is now confirmed in the blockchain!
    }
}
