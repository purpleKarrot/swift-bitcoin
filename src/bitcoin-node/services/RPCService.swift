import Foundation
import Logging
import ServiceLifecycle
import NIOCore
import NIOPosix

import JSONRPC
import NIOJSONRPC
import BitcoinCrypto
import BitcoinBase
import BitcoinBlockchain
import BitcoinTransport
import BitcoinRPC

private let logger = Logger(label: "swift-bitcoin.rpc")

actor RPCService: Service {

    init(host: String, port: Int, eventLoopGroup: EventLoopGroup, bitcoinNode: NodeService, blockchainService: BlockchainService, p2pService: P2PService, p2pClientServices: [P2PClientService]) {
        self.host = host
        self.port = port
        self.eventLoopGroup = eventLoopGroup
        self.bitcoinNode = bitcoinNode
        self.blockchainService = blockchainService
        self.p2pService = p2pService
        self.p2pClientServices = p2pClientServices
    }

    let host: String
    let port: Int
    let eventLoopGroup: EventLoopGroup
    let bitcoinNode: NodeService
    let blockchainService: BlockchainService
    let p2pService: P2PService
    let p2pClientServices: [P2PClientService]

    // Status and statistics
    private(set) var listening = false
    private(set) var overallConnections = 0
    private(set) var activeConnections = 0

    // State
    private var serviceGroup: ServiceGroup?

    func run() async throws {

        // Bootstraping server channel.
        let serverChannel = try await ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .bind(host: host, port: port) { channel in
                // This closure is called for every inbound connection.
                channel.pipeline.addHandlers([
                    IdleStateHandler(readTimeout: TimeAmount.seconds(5)),
                    HalfCloseOnTimeout(),
                    ByteToMessageHandler(NewlineEncoder()),
                    MessageToByteHandler(NewlineEncoder()),
                    CodableCodec<JSONRequest, JSONResponse>()
                ]).eventLoop.makeCompletedFuture {
                    try NIOAsyncChannel<JSONRequest, JSONResponse>(wrappingChannelSynchronously: channel)
                }
            }

        // Start listening
        try await withGracefulShutdownHandler {
            try await withThrowingDiscardingTaskGroup { @Sendable group in
                try await serverChannel.executeThenClose { serverChannelInbound in

                    logger.info("RPC server accepting incoming connections @ \(host):\(port)…")
                    await serviceUp()

                    for try await connectionChannel in serverChannelInbound.cancelOnGracefulShutdown() {

                        logger.info("Incoming RPC connection from client @ \(String(describing: connectionChannel.channel.remoteAddress))")
                        await connectionMade()

                        group.addTask {
                            do {
                                try await connectionChannel.executeThenClose {
                                    for try await request in $0.cancelOnGracefulShutdown() {
                                        try await self.handleRequest(request, $0, $1)
                                    }
                                }
                            } catch {
                                logger.error("An unexpected error has occurred:\n\(error)")
                            }

                            logger.info("RPC server disconnected from client @ \(String(describing: connectionChannel.channel.remoteAddress)).")
                            await self.clientDisconnected()
                        }
                    }
                    logger.info("No more incoming RPC connections.")
                }
                logger.info("RPC server stopped (no longer listening for connections).")
            }
        } onGracefulShutdown: {
            logger.info("RPC server shutting down gracefully…")
        }
    }

    func setServiceGroup(_ serviceGroup: ServiceGroup) {
        precondition(self.serviceGroup == nil)
        self.serviceGroup = serviceGroup
    }

    private func serviceUp() {
        listening = true
    }

    private func connectionMade() {
        activeConnections += 1
        overallConnections += 1
    }

    private func clientDisconnected() {
        activeConnections -= 1
    }

    private func handleRequest(_ request: JSONRequest, _ inbound: NIOAsyncChannelInboundStream<JSONRequest>, _ outbound: NIOAsyncChannelOutboundWriter<JSONResponse>) async throws -> () {
        switch request.method {
        case "stop":
            try await rpcStop(request, outbound: outbound)
        case "start-p2p":
            try await rpcStartP2P(request, outbound: outbound)
        case "stop-p2p":
            try await rpcStopP2P(request, outbound: outbound)
        case "connect":
            try await rpcConnect(request, outbound: outbound)
        case "disconnect":
            try await rpcDisconnect(request, outbound: outbound)
        case GetStatusCommand.method:
            try await rpcStatus(request, outbound: outbound)
        case GenerateToPublicKeyCommand.method:
            let command = GenerateToPublicKeyCommand(blockchainService: blockchainService)
            do {
                try await outbound.write(command.run(request))
            } catch let error as RPCError {
                try await outbound.write(.init(id: request.id, error: error))
            }
        case GetBlockCommand.method:
            let command = GetBlockCommand(blockchainService: blockchainService)
            do {
                try await outbound.write(command.run(request))
            } catch let error as RPCError {
                try await outbound.write(.init(id: request.id, error: error))
            }
        case GetTransactionCommand.method:
            let command = GetTransactionCommand(blockchainService: blockchainService)
            do {
                try await outbound.write(command.run(request))
            } catch let error as RPCError {
                try await outbound.write(.init(id: request.id, error: error))
            }
        case GetBlockchainInfoCommand.method:
            let command = GetBlockchainInfoCommand(blockchainService: blockchainService)
            try await outbound.write(command.run(request))
        case GetMempoolCommand.method:
            let command = GetMempoolCommand(blockchainService: blockchainService)
            try await outbound.write(command.run(request))
        case SendTransactionCommand.method:
            let command = SendTransactionCommand(bitcoinNode: bitcoinNode)
            do {
                try await command.run(request)
            } catch let error as RPCError {
                try await outbound.write(.init(id: request.id, error: error))
            }
        default:
            try await outbound.write(.init(id: request.id, error: .init(.invalidParams("method"), description: "Method `\(request.method)` does not exist.")))
        }
    }

    private func rpcStatus(_ request: JSONRequest, outbound: NIOAsyncChannelOutboundWriter<JSONResponse>) async throws {

        let status = RPCServiceStatus(listening: listening, host: host, port: port, overallConnections: overallConnections, activeConnections: activeConnections)

        // Collect P2P Client Services' statuses in order
        let p2pClientStatus = await withTaskGroup(of: (Int, P2PClientServiceStatus).self, returning: [P2PClientServiceStatus].self) { group in
            for i in p2pClientServices.indices {
                group.addTask {
                    let status = await self.p2pClientServices[i].status
                    return (i, status)
                }
            }
            var items = [(Int, P2PClientServiceStatus)]()
            for await var result in group {
                result.1.index = result.0 // Set the index inside the struct
                items.append(result)
            }
            return items.sorted(by: { $0.0 < $1.0 }).map(\.1) // Get rid of the tuple index
        }

        // Execute RPC Command
        let command = GetStatusCommand(rpcStatus: status, p2pStatus: await p2pService.status, p2pClientStatus: p2pClientStatus)
        try await outbound.write(command.run(request))
    }

    private func rpcStop(_ request: JSONRequest, outbound: NIOAsyncChannelOutboundWriter<JSONResponse>) async throws {
        try await outbound.write(.init(id: request.id, result: .string("Stopping…") as JSONObject))
        await serviceGroup?.triggerGracefulShutdown()
    }

    private func rpcStartP2P(_ request: JSONRequest, outbound: NIOAsyncChannelOutboundWriter<JSONResponse>) async throws {
            if case let .list(objects) = RPCObject(request.params),
               objects.count > 1,
               case let .string(host) = objects[0],
               case let .integer(port) = objects[1] {
                try await outbound.write(.init(id: request.id, result: .string("Staring P2P server on \(host):\(port)…") as JSONObject))
                await p2pService.start(host: host, port: port)
            } else {
                try await outbound.write(.init(id: request.id, error: .init(.invalidParams("Port (integer) is required."))))
            }
    }

    private func rpcStopP2P(_ request: JSONRequest, outbound: NIOAsyncChannelOutboundWriter<JSONResponse>) async throws {
            try await outbound.write(.init(id: request.id, result: .string("Stopping P2P server…") as JSONObject))
            try await p2pService.stopListening()
    }

    private func rpcConnect(_ request: JSONRequest, outbound: NIOAsyncChannelOutboundWriter<JSONResponse>) async throws {
        guard case let .list(objects) = RPCObject(request.params),
              objects.count > 1,
              case let .string(host) = objects[0],
              case let .integer(port) = objects[1] else {
            try await outbound.write(.init(id: request.id, error: .init(.invalidParams("host,port"), description: "Host (string) and port (integer) are required.")))
            return // or break?
        }
        // Attempt to find an inactive client.
        var clientService = P2PClientService?.none
        for service in p2pClientServices {
            if await !service.connected {
                clientService = service
                break
            }
        }
        guard let clientService else {
            try await outbound.write(.init(id: request.id, error: .init(.applicationError("Maximum P2P client instances reached."))))
            return
        }

        try await outbound.write(.init(id: request.id, result: .string("Connecting to peer @\(host):\(port)…") as JSONObject))
        await clientService.connect(host: host, port: port)
    }

    private func rpcDisconnect(_ request: JSONRequest, outbound: NIOAsyncChannelOutboundWriter<JSONResponse>) async throws {
        if case let .list(objects) = RPCObject(request.params), let first = objects.first, case let .integer(localPort) = first {
            try await outbound.write(.init(id: request.id, result: .string("Disconnecting from client @\(localPort)…") as RPCObject))

            // Attempt to find a non-running client.
            var clientService = P2PClientService?.none
            for service in p2pClientServices {
                if await service.localPort == localPort {
                    clientService = service
                }
            }
            guard let clientService else {
                try await outbound.write(.init(id: request.id, error: .init(.applicationError("No client connected @\(localPort)"))))
                return
            }

            try await clientService.disconnect()
        } else {
            try await outbound.write(.init(id: request.id, error: .init(.invalidParams("Port (integer) is required."))))
        }
    }
}
