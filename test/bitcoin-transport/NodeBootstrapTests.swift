import Testing
import BitcoinCrypto
import Foundation
import AsyncAlgorithms
import BitcoinBase
import BitcoinWallet
import BitcoinBlockchain
@testable import BitcoinTransport

private let secretKey = SecretKey([0x49, 0xc3, 0xa4, 0x4b, 0xf0, 0xe2, 0xb8, 0x1e, 0x4a, 0x74, 0x11, 0x02, 0xb4, 0x08, 0xe3, 0x11, 0x70, 0x2c, 0x7e, 0x3b, 0xe0, 0x21, 0x5c, 0xa2, 0xc4, 0x66, 0xb3, 0xb5, 0x4d, 0x9c, 0x54, 0x63])!

private let pubkey = PubKey([0x02, 0xc8, 0xd2, 0x1f, 0x79, 0x52, 0x9d, 0xee, 0xaa, 0x27, 0x69, 0x19, 0x8d, 0x3d, 0xf6, 0x20, 0x9a, 0x06, 0x4c, 0x99, 0x15, 0xae, 0x55, 0x7f, 0x7a, 0x9d, 0x01, 0xd7, 0x24, 0x59, 0x0d, 0x63, 0x34])!

/// Initializing node/peer state to avoid simulating the message sequence that would lead to that state.
struct NodeBootstrapTests {

    @Test("Ping Pong")
    func pingPong() async throws {
        // Setup blockchains
        let aliceChain = BlockchainService(params: .swiftTesting)
        let bobChain = BlockchainService(params: .swiftTesting)

        // Alice's node
        let peerB = UUID()
        let alice = NodeService(
            blockchain: aliceChain,
            config: .init(keepAliveFrequency: .none),
            state: NodeState(ibdComplete: true, peers: [peerB : makePeerState()])
        )
        await #expect(alice.state.peers[peerB]!.handshakeComplete)

        // Bob's node
        let peerA = UUID()
        let bob = NodeService(
            blockchain: bobChain,
            config: .init(keepAliveFrequency: .none),
            state: NodeState(ibdComplete: true, peers: [peerA : makePeerState(true)])
        )
        await #expect(bob.state.peers[peerA]!.handshakeComplete)

        // Start nodes
        await alice.start()
        await bob.start()

        // Channels
        var aliceToBob = await alice.getChannel(for: peerB).makeAsyncIterator()
        // var bobToAlice = await bob.getChannel(for: peerA).makeAsyncIterator()

        // Begin testing
        Task {
            await alice.sendPingTo(peerB)
        }
        // Alice --(ping)->> …
        let messageAB0_ping = try #require(await aliceToBob.next())
        await Task.yield()
        #expect(messageAB0_ping.command == .ping)

        let ping = try #require(PingMessage(messageAB0_ping.payload))
        var lastPingNonce = await alice.state.peers[peerB]!.lastPingNonce
        #expect(lastPingNonce != nil)

        // … --(ping)->> Bob
        try await bob.processMessage(messageAB0_ping, from: peerA)

        // Bob --(pong)->> …
        let messageBA0_pong = try #require(await bob.popMessage(peerA))
        #expect(messageBA0_pong.command == .pong)

        let pong = try #require(PongMessage(messageBA0_pong.payload))
        #expect(ping.nonce == pong.nonce)

        // … --(pong)->> Alice
        try await alice.processMessage(messageBA0_pong, from: peerB) // No response expected

        lastPingNonce = await alice.state.peers[peerB]!.lastPingNonce
        #expect(lastPingNonce == nil)

        await cleanup([alice, bob])
    }

    @Test("Empty block relay")
    func emptyBlockRelay() async throws {
        // Setup blockchains
        let aliceChain = BlockchainService(params: .swiftTesting)
        let bobChain = BlockchainService(params: .swiftTesting)
        let carolChain = BlockchainService(params: .swiftTesting)

        // Alices's node
        let peerB = UUID()
        let alice = NodeService(
            blockchain: aliceChain,
            config: .init(keepAliveFrequency: .none),
            state: NodeState(ibdComplete: true, peers: [peerB : makePeerState()])
        )

        // Bob's node
        let peerA = UUID()
        let peerC = UUID() // Carol on Bob's node
        let bob = NodeService(blockchain: bobChain, config: .init(keepAliveFrequency: .none), state: NodeState(ibdComplete: true, peers: [peerA : makePeerState(true), peerC : makePeerState()]))

        // Carol's node
        let carolPeerB = UUID() // Bob on Carol's node
        let carol = NodeService(blockchain: carolChain, config: .init(keepAliveFrequency: .none), state: NodeState(ibdComplete: true, peers: [carolPeerB : makePeerState(true)]))

        // Start nodes
        await alice.start()
        await bob.start()
        await carol.start()

        // Peer channels
        var aliceToBob = await alice.getChannel(for: peerB).makeAsyncIterator()
        // var bobToAlice = await bob.getChannel(for: peerA).makeAsyncIterator()
        var bobToCarol = await bob.getChannel(for: peerC).makeAsyncIterator()
        // var carolToBob = await carol.getChannel(for: carolPeerB).makeAsyncIterator()

        // Inventory channels
        var aliceBlocks = try #require(await alice.blocks?.makeAsyncIterator())
        var bobBlocks = try #require(await bob.blocks?.makeAsyncIterator())
        var carolBlocks = try #require(await carol.blocks?.makeAsyncIterator())

        // Begin testing
        Task {
            await aliceChain.generateTo(pubkey)
        }
        let aliceBlock1 = try #require(await aliceBlocks.next())
        await Task.yield()

        let block1 = await aliceChain.blocks[1]
        #expect(aliceBlock1 == block1)

        Task {
            await alice.handleBlock(aliceBlock1)
        }

        // Alice --(cmpctblock)->> …
        let messageAB0_cmpctblock = try #require(await aliceToBob.next())
        await Task.yield()
        #expect(messageAB0_cmpctblock.command == .cmpctblock)

        let cmpctblock = try #require(CompactBlockMessage(messageAB0_cmpctblock.payload))
        #expect(cmpctblock.header == block1.header)

        // … --(cmpctblock)->> Bob
        try await bob.processMessage(messageAB0_cmpctblock, from: peerA)

        let bobBlock1 = try #require(await bobBlocks.next())

        Task {
            await bob.handleBlock(bobBlock1)
        }

        // Bob --(cmpctblock)->> …
        let messageBC0_cmpctblock = try #require(await bobToCarol.next())
        await Task.yield()
        #expect(messageBC0_cmpctblock.command == .cmpctblock)

        let cmpctblock2 = try #require(CompactBlockMessage(messageBC0_cmpctblock.payload))
        #expect(cmpctblock2.header == block1.header)

        // … --(cmpctblock)->> Carol
        try await carol.processMessage(messageBC0_cmpctblock, from: carolPeerB)

        let carolBlock1 = try #require(await carolBlocks.next())

        // No need to wrap this in a task since it will not produce the side effect of posting to the blocks channel
        await carol.handleBlock(carolBlock1)

        let bobsBlocks = await bob.blockchain.blocks
        #expect(await alice.blockchain.blocks == bobsBlocks)
        #expect(await carol.blockchain.blocks == bobsBlocks)

        await cleanup([alice, bob, carol])
    }

    @Test("Mempool transaction relay")
    func mempoolTxRelay() async throws {
        // Setup blockchains
        let aliceChain = BlockchainService(params: .swiftTesting)
        let bobChain = BlockchainService(params: .swiftTesting)
        let carolChain = BlockchainService(params: .swiftTesting)

        await aliceChain.generateTo(pubkey)
        let aliceTip  = await aliceChain.tip
        #expect(aliceTip == 2)

        // let pubkey = try #require(PubKey(compressed: [0x03, 0x5a, 0xc9, 0xd1, 0x48, 0x78, 0x68, 0xec, 0xa6, 0x4e, 0x93, 0x2a, 0x06, 0xee, 0x8d, 0x6d, 0x2e, 0x89, 0xd9, 0x86, 0x59, 0xdb, 0x7f, 0x24, 0x74, 0x10, 0xd3, 0xe7, 0x9f, 0x88, 0xf8, 0xd0, 0x05])) // Testnet p2pkh address  miueyHbQ33FDcjCYZpVJdC7VBbaVQzAUg5
        for i in 1 ..< aliceTip {
            try await bobChain.processBlock(await aliceChain.blocks[i])
            try await carolChain.processBlock(await aliceChain.blocks[i])
        }

        #expect(await bobChain.tip == aliceTip)
        #expect(await carolChain.tip == aliceTip)

        // Grab block 1's coinbase transaction and output.
        let coinbaseTx = await aliceChain.getBlock(1).txs[0]

        var tx = BitcoinTx(
            ins: [.init(outpoint: coinbaseTx.outpoint(0))],
            outs: [
                .init(value: 1000, script: .payToPubkeyHash(pubkey))
            ])

        let signer = TxSigner(tx: tx, prevouts: [coinbaseTx.outs[0]])
        signer.sign(txIn: 0, with: secretKey)
        tx = signer.tx

        // Alice's node
        let peerB = UUID()
        let alice = NodeService(
            blockchain: aliceChain,
            config: .init(keepAliveFrequency: .none),
            state: NodeState(ibdComplete: true, peers: [peerB : makePeerState()])
        )

        // Bob's node
        let peerA = UUID()
        let peerC = UUID() // Carol on Bob's node
        let bob = NodeService(blockchain: bobChain, config: .init(keepAliveFrequency: .none), state: NodeState(ibdComplete: true, peers: [peerA : makePeerState(true), peerC : makePeerState()]))

        // Carol node
        let carolPeerB = UUID() // Bob on Carol's node
        let carol = NodeService(blockchain: carolChain, config: .init(keepAliveFrequency: .none), state: NodeState(ibdComplete: true, peers: [carolPeerB : makePeerState(true)]))

        // Start nodes
        await alice.start()
        await bob.start()
        await carol.start()

        // Peer channels
        var aliceToBob = await alice.getChannel(for: peerB).makeAsyncIterator()
        // var bobToAlice = await bob.getChannel(for: peerA).makeAsyncIterator()
        var bobToCarol = await bob.getChannel(for: peerC).makeAsyncIterator()
        // var carolToBob = await carol.getChannel(for: carolPeerB).makeAsyncIterator()

        // Inventory channels
        var aliceTxs = try #require(await alice.txs?.makeAsyncIterator())
        var bobTxs = try #require(await bob.txs?.makeAsyncIterator())
        var carolTxs = try #require(await carol.txs?.makeAsyncIterator())

        // Begin testing
        Task {
            try await aliceChain.addTx(tx)
        }
        let aliceTx = try #require(await aliceTxs.next())
        await Task.yield()

        Task {
            await alice.handleTx(aliceTx)
        }
        // Alice --(inv)->> …
        let messageAB0_inv = try #require(await aliceToBob.next())
        await Task.yield()
        #expect(messageAB0_inv.command == .inv)

        let inv = try #require(InventoryMessage(messageAB0_inv.payload))
        #expect(inv.items == [.init(type: .witnessTx, hash: tx.id)])

        // … --(inv)->> Bob
        try await bob.processMessage(messageAB0_inv, from: peerA)

        // Bob --(getdata)->> …
        let messageBA0_getdata = try #require(await bob.popMessage(peerA))
        #expect(messageBA0_getdata.command == .getdata)

        let getData = try #require(GetDataMessage(messageBA0_getdata.payload))
        #expect(getData.items == [.init(type: .witnessTx, hash: tx.id)])

        // … --(getdata)->> Alice
        try await alice.processMessage(messageBA0_getdata, from: peerB)

        // Alice --(tx)->> …
        let messageAB1_tx = try #require(await alice.popMessage(peerB))
        #expect(messageAB1_tx.command == .tx)

        let txMessage = try #require(BitcoinTx(messageAB1_tx.payload))
        #expect(txMessage == tx)

        // … --(tx)->> Bob
        try await bob.processMessage(messageAB1_tx, from: peerA)

        let bobTx = try #require(await bobTxs.next())

        Task {
            await bob.handleTx(bobTx)
        }
        // Bob --(inv)->> …
        let messageBC0_inv = try #require(await bobToCarol.next())
        await Task.yield()
        #expect(messageBC0_inv.command == .inv)

        let inv2 = try #require(InventoryMessage(messageBC0_inv.payload))
        #expect(inv2.items == [.init(type: .witnessTx, hash: tx.id)])

        // … --(inv)->> Carol
        try await carol.processMessage(messageBC0_inv, from: carolPeerB)

        // Carol --(getdata)->> …
        let messageCB0_getdata = try #require(await carol.popMessage(carolPeerB))
        #expect(messageCB0_getdata.command == .getdata)

        let getData2 = try #require(GetDataMessage(messageCB0_getdata.payload))
        #expect(getData2.items == [.init(type: .witnessTx, hash: tx.id)])

        // … --(getdata)->> Bob
        try await bob.processMessage(messageCB0_getdata, from: peerC)

        // Bob --(tx)->> …
        let messageBC1_tx = try #require(await bob.popMessage(peerC))
        #expect(messageBC1_tx.command == .tx)

        let txMessage1 = try #require(BitcoinTx(messageBC1_tx.payload))
        #expect(txMessage1 == tx)

        // … --(tx)->> Carol
        try await carol.processMessage(messageBC1_tx, from: carolPeerB)

        let carolTx = try #require(await carolTxs.next())

        // No need to wrap this in a task since it will not produce the side effect of posting to the txs channel
        await carol.handleTx(carolTx)

        let bobsMempool = await bob.blockchain.mempool
        #expect(await alice.blockchain.mempool == bobsMempool)
        #expect(await carol.blockchain.mempool == bobsMempool)

        await cleanup([alice, bob, carol])
    }

    @Test("Compact block (high bandwidth mode)")
    func  compactBlockHighBandwidth() async throws {
        // Setup blockchains
        let aliceChain = BlockchainService(params: .swiftTesting)
        let bobChain = BlockchainService(params: .swiftTesting)
        let carolChain = BlockchainService(params: .swiftTesting)

        await aliceChain.generateTo(pubkey)
        let aliceTip  = await aliceChain.tip
        for i in 1 ..< aliceTip {
            try await bobChain.processBlock(await aliceChain.blocks[i])
            try await carolChain.processBlock(await aliceChain.blocks[i])
        }

        // Grab block 1's coinbase transaction and output.
        let coinbaseTx = await aliceChain.getBlock(1).txs[0]

        var tx = BitcoinTx(
            ins: [.init(outpoint: coinbaseTx.outpoint(0))],
            outs: [
                .init(value: 1000, script: .payToPubkeyHash(pubkey))
            ])

        let signer = TxSigner(tx: tx, prevouts: [coinbaseTx.outs[0]])
        signer.sign(txIn: 0, with: secretKey)
        tx = signer.tx

        try await aliceChain.addTx(tx)
        try await bobChain.addTx(tx)

        // Carol will not have a copy of the transaction therefore will have to request it
        // try await carolChain.addTx(tx)

        // Alices's node
        let peerB = UUID()
        let alice = NodeService(
            blockchain: aliceChain,
            config: .init(keepAliveFrequency: .none),
            state: NodeState(ibdComplete: true, peers: [peerB : makePeerState()])
        )

        // Bob's node
        let peerA = UUID()
        let peerC = UUID() // Carol on Bob's node
        let bob = NodeService(blockchain: bobChain, config: .init(keepAliveFrequency: .none), state: NodeState(ibdComplete: true, peers: [peerA : makePeerState(true), peerC : makePeerState()]))

        // Carol's node
        let carolPeerB = UUID() // Bob on Carol's node
        let carol = NodeService(blockchain: carolChain, config: .init(keepAliveFrequency: .none), state: NodeState(ibdComplete: true, peers: [carolPeerB : makePeerState(true)]))

        // Start nodes
        await alice.start()
        await bob.start()
        await carol.start()

        // Peer channels
        var aliceToBob = await alice.getChannel(for: peerB).makeAsyncIterator()
        // var bobToAlice = await bob.getChannel(for: peerA).makeAsyncIterator()
        var bobToCarol = await bob.getChannel(for: peerC).makeAsyncIterator()
        // var carolToBob = await carol.getChannel(for: carolPeerB).makeAsyncIterator()

        // Inventory channels
        var aliceBlocks = try #require(await alice.blocks?.makeAsyncIterator())
        var bobBlocks = try #require(await bob.blocks?.makeAsyncIterator())
        var carolBlocks = try #require(await carol.blocks?.makeAsyncIterator())

        // Begin testing
        Task {
            await aliceChain.generateTo(pubkey)
        }
        let aliceBlock2 = try #require(await aliceBlocks.next())
        await Task.yield()

        let block2 = await aliceChain.blocks[2]
        #expect(aliceBlock2 == block2)

        Task {
            await alice.handleBlock(aliceBlock2)
        }

        // Alice --(cmpctblock)->> …
        let messageAB0_cmpctblock = try #require(await aliceToBob.next())
        await Task.yield()
        #expect(messageAB0_cmpctblock.command == .cmpctblock)

        let cmpctblock = try #require(CompactBlockMessage(messageAB0_cmpctblock.payload))
        #expect(cmpctblock.header == block2.header)

        // … --(cmpctblock)->> Bob
        try await bob.processMessage(messageAB0_cmpctblock, from: peerA)

        let bobBlock1 = try #require(await bobBlocks.next())

        Task {
            await bob.handleBlock(bobBlock1)
        }

        // Bob --(cmpctblock)->> …
        let messageBC0_cmpctblock = try #require(await bobToCarol.next())
        await Task.yield()
        #expect(messageBC0_cmpctblock.command == .cmpctblock)

        let cmpctblock2 = try #require(CompactBlockMessage(messageBC0_cmpctblock.payload))
        #expect(cmpctblock2.header == block2.header)

        // … --(cmpctblock)->> Carol
        try await carol.processMessage(messageBC0_cmpctblock, from: carolPeerB)

        // Carol --(getblocktxn)->> …
        let messageCB0_getblocktxn = try #require(await carol.popMessage(carolPeerB))
        #expect(messageCB0_getblocktxn.command == .getblocktxn)

        let getblocktxn = try #require(GetBlockTxsMessage(messageCB0_getblocktxn.payload))
        #expect(getblocktxn.blockHash == block2.id)
        #expect(getblocktxn.txIndices == [1])

        // … --(getblocktxn)->> Bob
        try await bob.processMessage(messageCB0_getblocktxn, from: peerC)

        // Bob --(blocktxn)->> …
        let messageBC1_blocktxn = try #require(await bob.popMessage(peerC))
        #expect(messageBC1_blocktxn.command == .blocktxn)

        let blocktxn = try #require(BlockTxsMessage(messageBC1_blocktxn.payload))
        #expect(blocktxn.txs == [tx])

        // … --(blocktxn)->> Carol
        try await carol.processMessage(messageBC1_blocktxn, from: carolPeerB)

        let carolBlock2 = try #require(await carolBlocks.next())

        // No need to wrap this in a task since it will not produce the side effect of posting to the blocks channel
        await carol.handleBlock(carolBlock2)

        let bobsBlocks = await bob.blockchain.blocks
        #expect(await alice.blockchain.blocks == bobsBlocks)
        #expect(await carol.blockchain.blocks == bobsBlocks)

        await cleanup([alice, bob, carol])
    }

    @Test("Compact block (low bandwidth mode)")
    func  compactBlockLowBandwidth() async throws {
        // Setup blockchains
        let aliceChain = BlockchainService(params: .swiftTesting)
        let bobChain = BlockchainService(params: .swiftTesting)
        let carolChain = BlockchainService(params: .swiftTesting)

        await aliceChain.generateTo(pubkey)
        let aliceTip  = await aliceChain.tip

        for i in 1 ..< aliceTip {
            try await bobChain.processBlock(await aliceChain.blocks[i])
            try await carolChain.processBlock(await aliceChain.blocks[i])
        }

        // Grab block 1's coinbase transaction and output.
        let coinbaseTx = await aliceChain.getBlock(1).txs[0]

        var tx = BitcoinTx(
            ins: [.init(outpoint: coinbaseTx.outpoint(0))],
            outs: [
                .init(value: 1000, script: .payToPubkeyHash(pubkey))
            ])

        let signer = TxSigner(tx: tx, prevouts: [coinbaseTx.outs[0]])
        signer.sign(txIn: 0, with: secretKey)
        tx = signer.tx

        try await aliceChain.addTx(tx)
        try await bobChain.addTx(tx)

        // Carol will not have a copy of the transaction therefore will have to request it
        // try await carolChain.addTx(tx)

        // Alices's node
        let peerB = UUID()
        let alice = NodeService(
            blockchain: aliceChain,
            config: .init(keepAliveFrequency: .none),
            state: NodeState(ibdComplete: true, peers: [peerB : makePeerState(highBandwidth: false)])
        )

        // Bob's node
        let peerA = UUID()
        let peerC = UUID() // Carol on Bob's node
        let bob = NodeService(blockchain: bobChain, config: .init(keepAliveFrequency: .none), state: NodeState(ibdComplete: true, peers: [peerA : makePeerState(true), peerC : makePeerState(highBandwidth: false)]))

        // Carol's node
        let carolPeerB = UUID() // Bob on Carol's node
        let carol = NodeService(blockchain: carolChain, config: .init(keepAliveFrequency: .none), state: NodeState(ibdComplete: true, peers: [carolPeerB : makePeerState(true)]))

        // Start nodes
        await alice.start()
        await bob.start()
        await carol.start()

        // Peer channels
        var aliceToBob = await alice.getChannel(for: peerB).makeAsyncIterator()
        // var bobToAlice = await bob.getChannel(for: peerA).makeAsyncIterator()
        var bobToCarol = await bob.getChannel(for: peerC).makeAsyncIterator()
        // var carolToBob = await carol.getChannel(for: carolPeerB).makeAsyncIterator()

        // Inventory channels
        var aliceBlocks = try #require(await alice.blocks?.makeAsyncIterator())
        var bobBlocks = try #require(await bob.blocks?.makeAsyncIterator())
        var carolBlocks = try #require(await carol.blocks?.makeAsyncIterator())

        // Begin testing
        Task {
            await aliceChain.generateTo(pubkey)
        }
        let aliceBlock2 = try #require(await aliceBlocks.next())
        await Task.yield()

        let block2 = await aliceChain.blocks[2]
        #expect(aliceBlock2 == block2)

        Task {
            await alice.handleBlock(aliceBlock2)
        }

        // Alice --(headers)->> …
        let messageAB0_headers = try #require(await aliceToBob.next())
        await Task.yield()
        #expect(messageAB0_headers.command == .headers)

        let headers = try #require(HeadersMessage(messageAB0_headers.payload))
        #expect(headers.items == [block2.header])

        // … --(header)->> Bob
        try await bob.processMessage(messageAB0_headers, from: peerA)

        // Bob --(getdata)->> …
        let messageBA0_getdata = try #require(await bob.popMessage(peerA))
        #expect(messageBA0_getdata.command == .getdata)

        let getData = try #require(GetDataMessage(messageBA0_getdata.payload))
        #expect(getData.items == [.init(type: .compactBlock, hash: block2.id)])

        // … --(getdata)->> Alice
        try await alice.processMessage(messageBA0_getdata, from: peerB)

        // Alice --(cmpctblock)->> …
        let messageAB1_cmpctblock = try #require(await alice.popMessage(peerB))
        #expect(messageAB1_cmpctblock.command == .cmpctblock)

        let cmpctblock = try #require(CompactBlockMessage(messageAB1_cmpctblock.payload))
        #expect(cmpctblock.header == block2.header)

        // … --(cmpctblock)->> Bob
        try await bob.processMessage(messageAB1_cmpctblock, from: peerA)
        #expect(await bobChain.tip == 3)

        let bobBlock2 = try #require(await bobBlocks.next())

        Task {
            await bob.handleBlock(bobBlock2)
        }

        // Bob --(headers)->> …
        let messageBC0_headers = try #require(await bobToCarol.next())
        await Task.yield()
        #expect(messageBC0_headers.command == .headers)

        let headers2 = try #require(HeadersMessage(messageBC0_headers.payload))
        #expect(headers2.items == [block2.header])

        // … --(headers)->> Carol
        try await carol.processMessage(messageBC0_headers, from: carolPeerB)

        // Carol --(getdata)->> …
        let messageCB0_getdata = try #require(await carol.popMessage(carolPeerB))
        #expect(messageCB0_getdata.command == .getdata)

        let getData2 = try #require(GetDataMessage(messageCB0_getdata.payload))
        #expect(getData2.items == [.init(type: .compactBlock, hash: block2.id)])

        // … --(getdata)->> Bob
        try await bob.processMessage(messageCB0_getdata, from: peerC)

        // Bob --(cmpctblock)->> …
        let messageBC0_cmpctblock = try #require(await bob.popMessage(peerC))
        await Task.yield()
        #expect(messageBC0_cmpctblock.command == .cmpctblock)

        let cmpctblock2 = try #require(CompactBlockMessage(messageBC0_cmpctblock.payload))
        #expect(cmpctblock2.header == block2.header)

        // … --(cmpctblock)->> Carol
        try await carol.processMessage(messageBC0_cmpctblock, from: carolPeerB)

        // Carol --(getblocktxn)->> …
        let messageCB0_getblocktxn = try #require(await carol.popMessage(carolPeerB))
        #expect(messageCB0_getblocktxn.command == .getblocktxn)

        let getblocktxn = try #require(GetBlockTxsMessage(messageCB0_getblocktxn.payload))
        #expect(getblocktxn.blockHash == block2.id)
        #expect(getblocktxn.txIndices == [1])

        // … --(getblocktxn)->> Bob
        try await bob.processMessage(messageCB0_getblocktxn, from: peerC)

        // Bob --(blocktxn)->> …
        let messageBC1_blocktxn = try #require(await bob.popMessage(peerC))
        #expect(messageBC1_blocktxn.command == .blocktxn)

        let blocktxn = try #require(BlockTxsMessage(messageBC1_blocktxn.payload))
        #expect(blocktxn.txs == [tx])

        // … --(blocktxn)->> Carol
        try await carol.processMessage(messageBC1_blocktxn, from: carolPeerB)

        let carolBlock2 = try #require(await carolBlocks.next())

        // No need to wrap this in a task since it will not produce the side effect of posting to the blocks channel
        await carol.handleBlock(carolBlock2)

        let bobsBlocks = await bob.blockchain.blocks
        #expect(await alice.blockchain.blocks == bobsBlocks)
        #expect(await carol.blockchain.blocks == bobsBlocks)

        await cleanup([alice, bob, carol])
    }
}

private func cleanup(_ services: [NodeService]) async {
    for s in services {
        for p in await s.state.peers.keys {
            await s.removePeer(p)
        }
        await s.stop()
        await s.blockchain.shutdown()
    }
}

private func makePeerState(_ incoming: Bool = false, highBandwidth: Bool = true) -> PeerState {
    var ps = PeerState(address: IPv6Address.unspecified, port: 0, incoming: incoming)
    ps.version = .init()
    ps.witnessRelayPreferenceReceived = true
    ps.v2AddressPreferenceReceived = true
    ps.versionAckReceived = true
    ps.compactBlocksVersion = 2
    ps.compactBlocksPreferenceSent = true
    ps.compactBlocksVersionLocked = true
    ps.highBandwidthCompactBlocks = highBandwidth
    return ps
}
