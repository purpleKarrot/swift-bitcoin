import Foundation
import AsyncAlgorithms
import BitcoinBase
import BitcoinBlockchain

private let keepAliveSeconds = 60
private let pongToleranceSeconds = 15

/// Manages connection with state.peers, process incoming messages and sends responses.
public actor NodeService: Sendable {

    ///  Creates an instance of a bitcoin node service.
    /// - Parameters:
    ///   - blockchainService: The bitcoin service actor instance backing this node.
    ///   - network: The type of bitcoin network this node is part of.
    ///   - version: Protocol version number.
    ///   - services: Supported services.
    ///   - feeFilterRate: An arbitrary fee rate by which to filter transactions.
    public init(blockchainService: BlockchainService, config: NodeConfig = .default, state: NodeState = .initial) {
        self.blockchainService = blockchainService
        self.config = config
        self.state = state
        for id in state.peers.keys {
            peerOuts[id] = .init()
        }
    }

    /// The bitcoin service actor instance backing this node.
    public let blockchainService: BlockchainService

    public let config: NodeConfig
    public var state: NodeState

    /// Subscription to the bitcoin service's blocks channel.
    public var blocks = AsyncChannel<TxBlock>?.none

    /// IP address as string.
    var address = IPv6Address?.none

    /// Our port might not exist if peer-to-peer server is down. We can still be conecting with state.peers as a client.
    var port = Int?.none

    /// Channel for delivering message to state.peers.
    var peerOuts = [UUID : AsyncChannel<BitcoinMessage>]()

    /// The node's randomly generated identifier (nonce). This is sent with `version` messages.
    let nonce = UInt64.random(in: UInt64.min ... UInt64.max)

    /// Called when the peer-to-peer service stops listening for incoming connections.
    public func resetAddress() {
        address = .none
        port = .none
    }

    /// Receive address information from the peer-to-peer service whenever it's actively listening.
    public func setAddress(_ host: String, _ port: Int) {
        self.address = IPv6Address.fromHost(host)
        self.port = port
    }

    public func start() async {
        blocks = await blockchainService.subscribeToBlocks()
    }

    public func handleBlock(_ block: TxBlock) async {
        await withDiscardingTaskGroup {
            for id in state.peers.keys {
                $0.addTask {
                    await self.sendBlock(block, to: id)
                }
            }
        }
    }

    /// We unsubscribe from Bitcoin service's blocks.
    public func stop() async {
        if let blocks {
            await blockchainService.unsubscribe(blocks)
        }
    }

    public func addTx(_ tx: BitcoinTx) async throws {
        try await blockchainService.addTx(tx)
        await withDiscardingTaskGroup {
            for id in state.peers.keys {
                $0.addTask {
                    await self.sendTx(tx, to: id)
                }
            }
        }
    }

    /// Send a ping to each of our state.peers. Calling this function will create child tasks.
    public func pingAll() async {
        await withDiscardingTaskGroup {
            for id in state.peers.keys {
                $0.addTask {
                    await self.sendPingTo(id)
                }
            }
        }
    }

    /// Request headers from peers.
    public func requestHeaders() async {
        let maxHeight = state.peers.values.reduce(-1) { max($0, $1.height) }
        let ourHeight = await blockchainService.headers.count - 1
        guard maxHeight > ourHeight,
              let (id, _) = state.peers.filter({ $0.value.height == maxHeight }).randomElement() else {
            return
        }
        await requestHeaders(id)
    }

    /// Request headers from a specific peer.
    func requestHeaders(_ id: UUID) async {
        guard let _ = state.peers[id] else { preconditionFailure() }
        let locatorHashes = await blockchainService.makeBlockLocator()
        let getHeaders = GetHeadersMessage(protocolVersion: .latest, locatorHashes: locatorHashes)
        state.awaitingHeadersFrom = id
        state.awaitingHeadersSince = .now
        enqueue(.getheaders, payload: getHeaders.data, to: id)
    }

    func requestNextMissingBlocks(_ id: UUID) async {
        guard let peer = state.peers[id] else { preconditionFailure() }

        let numberOfBlocksToRequest = config.maxInTransitBlocks - peer.inTransitBlocks
        guard numberOfBlocksToRequest > 0 else { return }

        let blockIDs = await blockchainService.getNextMissingBlocks(numberOfBlocksToRequest)

        guard !blockIDs.isEmpty else { return }

        let getData = GetDataMessage(items:
            blockIDs.map { .init(type: .witnessBlock, hash: $0) }
        )
        state.peers[id]?.inTransitBlocks += blockIDs.count
        enqueue(.getdata, payload: getData.data, to: id)
    }

    /// Registers a peer with the node. Incoming means we are the listener. Otherwise we are the node initiating the connection.
    public func addPeer(host: String = IPv4Address.empty.description, port: Int = 0, incoming: Bool = true) async -> UUID {
        let id = UUID()
        state.peers[id] = PeerState(address: IPv6Address.fromHost(host), port: port, incoming: incoming)
        peerOuts[id] = .init()
        return id
    }

    /// Deregisters a peer and cleans up outbound channels.
    public func removePeer(_ id: UUID) {
        state.peers[id]?.nextPingTask?.cancel()
        state.peers[id]?.checkPongTask?.cancel()
        peerOuts[id]?.finish()
        peerOuts.removeValue(forKey: id)
        state.peers.removeValue(forKey: id)
    }

    /// Returns a channel for a given peer's outbox. The caller can be notified of new messages generated for this peer.
    public func getChannel(for id: UUID) -> AsyncChannel<BitcoinMessage> {
        precondition(state.peers[id] != nil)
        return peerOuts[id]!
    }

    func makeVersion(for id: UUID) async -> VersionMessage {
        guard let peer = state.peers[id] else { preconditionFailure() }

        let lastBlock = await blockchainService.txs.count - 1
        return .init(
            protocolVersion: config.version,
            services: config.services,
            receiverServices: peer.version?.services,
            receiverAddress: peer.version?.transmitterAddress,
            receiverPort: peer.version?.transmitterPort,
            transmitterAddress: address,
            transmitterPort: port,
            nonce: nonce,
            startHeight: lastBlock)
    }

    /// Starts the handshake process but only if its an outgoing peer – i.e. we initiated the connection. Generates a child task for delivering the initial version message.
    public func connect(_ id: UUID) async {
        guard let peer = state.peers[id], peer.outgoing else { return }

        let versionMessage = await makeVersion(for: id)

        enqueue(.version, payload: versionMessage.data, to: id)
        enqueue(.wtxidrelay, to: id)
        enqueue(.sendaddrv2, to: id)
    }

    func sendTx(_ tx: BitcoinTx, to id: UUID) async {
        guard let _ = state.peers[id] else { return }
        let inventoryMessage = InventoryMessage(items: [.init(type: .witnessTx, hash: tx.witnessID)])
        await send(.inv, payload: inventoryMessage.data, to: id)
    }

    func sendBlock(_ block: TxBlock, to id: UUID) async {
        guard let _ = state.peers[id] else { return }
        let nonce = UInt64.random(in: UInt64.min ... UInt64.max)
        let compactBlockMesssage = CompactBlockMessage(header: block.header, nonce: nonce, txIDs: [block.makeShortTxID(for: 0, nonce: nonce)], txs: [.init(index: 0, tx: block.txs[0])])
        await send(.cmpctblock, payload: compactBlockMesssage.data, to: id)
    }

    // Sends a ping message to a peer. Creates a new child task.
    func sendPingTo(_ id: UUID, useQueue: Bool = false) async {
        guard let peer = state.peers[id], peer.lastPingNonce == .none else { return }

        // Prepare pong check
        state.peers[id]?.checkPongTask = Task.detached { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(pongToleranceSeconds) * 1_000_000_000)
            } catch { return }
            guard !Task.isCancelled, let self else { return }
            if let peer = await self.state.peers[id], peer.lastPingNonce != .none {
                await peerOuts[id]?.finish() // Trigger disconnection
            }
        }

        // Send ping
        let ping = PingMessage()
        state.peers[id]?.lastPingNonce = ping.nonce
        if useQueue {
            enqueue(.ping, payload: ping.data, to: id)
        } else {
            await send(.ping, payload: ping.data, to: id)
        }
    }

    public func popMessage(_ id: UUID) -> BitcoinMessage? {
        guard let peer = state.peers[id], !peer.outbox.isEmpty else { return .none }
        return state.peers[id]!.outbox.removeFirst()
    }

    /// Process an incoming message from a peer. This will sometimes result in sending out one or more messages back to the peer. The function will ultimately create a child task per message sent.
    public func processMessage(_ message: BitcoinMessage, from id: UUID) async throws {

        // Postpone the next ping
        state.peers[id]?.nextPingTask?.cancel()
        state.peers[id]?.nextPingTask = Task.detached { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(keepAliveSeconds) * 1_000_000_000)
            } catch { return }
            guard !Task.isCancelled, let self else { return }
            await self.sendPingTo(id)
        }

        guard let peer = state.peers[id] else { return }

        // First message must always be `version`.
        if peer.version == .none, message.command != .version {
            throw Error.versionMissing
        }

        switch message.command {
        case .version:
            try await processVersion(message, from: id)
        case .wtxidrelay:
            try await processWTXIDRelay(message, from: id)
        case .sendaddrv2:
            try await processSendAddrV2(message, from: id)
        case .verack:
            try await processVerack(message, from: id)
        case .sendcmpct:
            try processSendCompact(message, from: id)
        case .feefilter:
            try processFeeFilter(message, from: id)
        case .ping:
            try await processPing(message, from: id)
        case .pong:
            try processPong(message, from: id)
        case .getheaders:
            try await processGetHeaders(message, from: id)
        case .headers:
            try await processHeaders(message, from: id)
        case .block:
            try await processBlock(message, from: id)
        case .getdata:
            try await processGetData(message, from: id)
        case .cmpctblock:
            try await processCompactBlock(message, from: id)
        case .inv:
            try await processInventory(message, from: id)
        case .tx:
            try await processTx(message, from: id)
        case .getblocktxn, .blocktxn, .getaddr, .addrv2, .notfound, .unknown:
            break
        }
    }

    /// Sends a message.
    private func send(_ command: MessageCommand, payload: Data = .init(), to id: UUID) async {
        await peerOuts[id]?.send(.init(command, payload: payload, network: config.network))
    }

    /// Queues a message.
    private func enqueue(_ command: MessageCommand, payload: Data = .init(), to id: UUID) {
        state.peers[id]?.outbox.append(.init(command, payload: payload, network: config.network))
    }

    /// Processes an incoming version message as part of the handshake.
    private func processVersion(_ message: BitcoinMessage, from id: UUID) async throws {

        // Inbound connection sequence:
        // <- version (we receive the first message from the connecting peer)
        // -> version
        // -> wtxidrelay
        // -> sendaddrv2
        // <- verack
        // -> verack
        // -> sendcmpct
        // -> ping
        // -> getheaders
        // -> feefilter
        // <- pong

        guard let peer = state.peers[id] else { return }

        let ourTime = Date.now

        guard let peerVersion = VersionMessage(message.payload) else {
            preconditionFailure()
        }

        if peerVersion.nonce == nonce {
            throw Error.connectionToSelf
        }

        if peerVersion.services.intersection(config.services) != config.services {
            throw Error.unsupportedServices
        }

        // Inbound connection. Version message is the first message.
        if peerVersion.protocolVersion < config.version {
            throw Error.unsupportedVersion
        }

        state.peers[id]?.version = peerVersion
        state.peers[id]?.timeDiff = Int(ourTime.timeIntervalSince1970) - Int(peerVersion.timestamp.timeIntervalSince1970)
        state.peers[id]?.height = peerVersion.startHeight

        // Outbound connection. Version message is a response to our version.
        if peer.outgoing && peerVersion.protocolVersion > config.version {
            throw Error.unsupportedVersion
        }

        if peer.incoming {
            let versionMessage = await makeVersion(for: id)
            enqueue(.version, payload: versionMessage.data, to: id)
            enqueue(.wtxidrelay, to: id)
            enqueue(.sendaddrv2, to: id)
        }
    }

    /// BIP339
    private func processWTXIDRelay(_ message: BitcoinMessage, from id: UUID) async throws {
        guard let peer = state.peers[id] else { return }

        // Disconnect state.peers that send a WTXIDRELAY message after VERACK.
        if peer.versionAckReceived {
            // Because we disconnect nodes that don't signal for WTXID relay, this code will never be reached.
            throw Error.requestedWTXIDRelayAfterVerack
        }

        state.peers[id]?.witnessRelayPreferenceReceived = true

        if peer.v2AddressPreferenceReceived {
            enqueue(.verack, to: id)
        }
    }

    /// BIP155
    private func processSendAddrV2(_ message: BitcoinMessage, from id: UUID) async throws {
        guard let peer = state.peers[id] else { return }

        // Disconnect state.peers that send a SENDADDRV2 message after VERACK.
        if peer.versionAckReceived {
            // Because we disconnect nodes that don't ask for v2, this code will never be reached.
            throw Error.requestedV2AddrAfterVerack
        }

        state.peers[id]?.v2AddressPreferenceReceived = true

        if peer.witnessRelayPreferenceReceived {
            enqueue(.verack, to: id)
        }
    }

    private func processVerack(_ message: BitcoinMessage, from id: UUID) async throws {
        guard let peer = state.peers[id] else { return }

        if peer.versionAckReceived {
            // Ignore redundant verack.
            return
        }

        // BIP339
        if !peer.witnessRelayPreferenceReceived {
            throw Error.missingWTXIDRelayPreference
        }

        // BIP155
        if !peer.v2AddressPreferenceReceived {
            throw Error.missingV2AddrPreference
        }

        state.peers[id]?.versionAckReceived = true

        if state.peers[id]!.handshakeComplete {
            print("Handshake successful.")
        }

        // BIP152 send a burst of supported compact block versions followed by a ping to lock it down.
        enqueue(.sendcmpct, payload: SendCompactMessage().data, to: id)
        state.peers[id]?.compactBlocksPreferenceSent = true
        if let pong = peer.pongOnHoldUntilCompactBlocksPreference {
            enqueue(.pong, payload: pong.data, to: id)
            state.peers[id]?.pongOnHoldUntilCompactBlocksPreference = .none
        }
        await sendPingTo(id, useQueue: true)
        await requestHeaders(id)
        enqueue(.feefilter, payload: FeeFilterMessage(feeRate: state.feeFilterRate).data, to: id)
    }

    private func processPing(_ message: BitcoinMessage, from id: UUID) async throws {
        guard let peer = state.peers[id] else { return }

        guard let ping = PingMessage(message.payload) else {
            throw Error.invalidPayload
        }

        let pong = PongMessage(nonce: ping.nonce)

        // BIP152 We need to hold the pong until the compact block version was sent.
        if peer.compactBlocksPreferenceSent {
            enqueue(.pong, payload: pong.data, to: id)
        } else {
            state.peers[id]?.pongOnHoldUntilCompactBlocksPreference = pong
        }
    }

    private func processPong(_ message: BitcoinMessage, from id: UUID) throws {

        guard let peer = state.peers[id] else { return }

        guard let pong = PongMessage(message.payload) else {
            throw Error.invalidPayload
        }

        guard let nonce = peer.lastPingNonce, pong.nonce == nonce else {
            throw Error.pingPongMismatch
        }

        state.peers[id]?.lastPingNonce = .none
        state.peers[id]?.checkPongTask?.cancel()

        // BIP152: Lock compact block version on first pong.

        if peer.compactBlocksVersionLocked { return }

        guard let compactBlocksVersion = peer.compactBlocksVersion, compactBlocksVersion >= Self.minCompactBlocksVersion else {
            throw Error.unsupportedCompactBlocksVersion
        }
        state.peers[id]?.compactBlocksVersionLocked = true
    }

    /// BIP152
    private func processSendCompact(_ message: BitcoinMessage, from id: UUID) throws {
        guard let peer = state.peers[id] else { return }

        guard let sendCompact = SendCompactMessage(message.payload) else {
            throw Error.invalidPayload
        }

        // We let the negotiation play out for versions lower than our max supported. When version is finally locked we will enforce our minimum supported version as well.
        if peer.compactBlocksVersion == .none, sendCompact.version <= Self.maxCompactBlocksVersion {
            state.peers[id]?.highBandwidthCompactBlocks = sendCompact.highBandwidth
            state.peers[id]?.compactBlocksVersion = sendCompact.version
        }
    }

    /// BIP133
    private func processFeeFilter(_ message: BitcoinMessage, from id: UUID) throws {
        guard let feeFilter = FeeFilterMessage(message.payload) else {
            throw Error.invalidPayload
        }

        state.peers[id]?.feeFilterRate = feeFilter.feeRate
    }

    private func processGetHeaders(_ message: BitcoinMessage, from id: UUID) async throws {
        guard let _ = state.peers[id] else { return }

        guard let getHeaders = GetHeadersMessage(message.payload) else {
            throw Error.invalidPayload
        }

        let headers = await blockchainService.findHeaders(using: getHeaders.locatorHashes)
        let headersMessage = HeadersMessage(items: headers)

        enqueue(.headers, payload: headersMessage.data, to: id)
    }

    private func processHeaders(_ message: BitcoinMessage, from id: UUID) async throws {
        guard let _ = state.peers[id], let awaitingHeadersFrom = state.awaitingHeadersFrom, let awaitingHeadersSince = state.awaitingHeadersSince, awaitingHeadersFrom == id else { return }

        state.awaitingHeadersFrom = .none
        state.awaitingHeadersSince = .none

        if awaitingHeadersSince.timeIntervalSinceNow < -60 {
            return
        }

        guard let headersMessage = HeadersMessage(message.payload) else {
            throw Error.invalidPayload
        }
        do {
            try await blockchainService.processHeaders(headersMessage.items)
        } catch is BlockchainService.Error {
            state.peers[id]?.height = await blockchainService.headers.count - 1
        }

        if headersMessage.moreItems {
            await requestHeaders(id)
        }

        await requestNextMissingBlocks(id)
    }

    func processBlock(_ message: BitcoinMessage, from id: UUID) async throws {
        guard let _ = state.peers[id] else { preconditionFailure() }

        guard let blockMessage = TxBlock(message.payload) else {
            throw Error.invalidPayload
        }

        await blockchainService.processBlock(header: blockMessage.header, txs: blockMessage.txs)

        state.peers[id]?.inTransitBlocks -= 1

        if state.peers[id]!.inTransitBlocks == 0 {
            await requestNextMissingBlocks(id)
        }
    }

    func processGetData(_ message: BitcoinMessage, from id: UUID) async throws {
        guard let _ = state.peers[id] else { preconditionFailure() }

        guard let getDataMessage = GetDataMessage(message.payload) else {
            throw Error.invalidPayload
        }

        let blockHashes = getDataMessage.items.filter { $0.type == .witnessBlock }.map { $0.hash }
        if !blockHashes.isEmpty {
            let blocks = await blockchainService.getBlocks(blockHashes)

            for (header, txs) in blocks {
                let blockMessage = TxBlock(header: header, txs: txs)
                enqueue(.block, payload: blockMessage.data, to: id)
            }
        }

        let txHashes = getDataMessage.items.filter { $0.type == .witnessTx }.map { $0.hash }
        if !txHashes.isEmpty {
            guard let tx = await blockchainService.getTx(txHashes[0]) else { return }
            enqueue(.tx, payload: tx.data, to: id)
        }
    }

    func processInventory(_ message: BitcoinMessage, from id: UUID) async throws {
        guard let _ = state.peers[id] else { preconditionFailure() }

        guard let inventoryMessage = InventoryMessage(message.payload) else {
            throw Error.invalidPayload
        }

        for item in inventoryMessage.items {
            guard item.type == .witnessTx else { continue }
            if let _ = await blockchainService.getTx(item.hash) { continue }
            let getData = GetDataMessage(items: [
                .init(type: .witnessTx, hash: item.hash)
            ])
            await send(.getdata, payload: getData.data, to: id)
        }
    }

    func processTx(_ message: BitcoinMessage, from id: UUID) async throws {
        guard let _ = state.peers[id] else { preconditionFailure() }

        guard let tx = BitcoinTx(message.payload) else {
            throw Error.invalidPayload
        }
        try await blockchainService.addTx(tx)
    }

    func processCompactBlock(_ message: BitcoinMessage, from id: UUID) async throws {
        guard let _ = state.peers[id] else { preconditionFailure() }

        guard let compactBlockMessage = CompactBlockMessage(message.payload) else {
            throw Error.invalidPayload
        }

        // try await blockchainService.processHeaders([compactBlockMessage.header])
        // TODO: Process header first and then send getblocktxn for the non prefilled ones which we are lacking (check transaction ids)

        await blockchainService.processBlock(header: compactBlockMessage.header, txs: compactBlockMessage.txs.map { $0.tx })
    }

    static let minCompactBlocksVersion = 2
    static let maxCompactBlocksVersion = 2
}
