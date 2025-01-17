import BitcoinTransport
import ServiceLifecycle
import Logging

private let logger = Logger(label: "swift-bitcoin.node")

extension NodeService: Service {
    public func run() async throws {
        await withGracefulShutdownHandler {
            await start()
        } onGracefulShutdown: {
            logger.info("Node service shutting down gracefully…")
            Task {
                await self.stop()
                logger.info("Node service has shut down.")
            }
        }
    }
}
