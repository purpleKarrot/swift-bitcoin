import BitcoinTransport
import ServiceLifecycle
import Logging

private let logger = Logger(label: "swift-bitcoin.node")

extension NodeService: Service {
    public func run() async throws {
        await start()
        guard let blocks, let txs else { await stop(); return }

        await withGracefulShutdownHandler {
            await withDiscardingTaskGroup { group in
                group.addTask {
                    for await block in blocks.cancelOnGracefulShutdown() {
                        await self.handleBlock(block)
                    }
                }
                group.addTask {
                    for await tx in txs.cancelOnGracefulShutdown() {
                        await self.handleTx(tx)
                    }
                }
            }
            await stop()
        } onGracefulShutdown: {
            logger.info("BitcoinNode Service shutting down gracefully")
        }
    }
}
