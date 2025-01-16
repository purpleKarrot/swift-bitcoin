// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-bitcoin",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .watchOS(.v11),
        .tvOS(.v18),
        .visionOS(.v2)
    ],
    products: [
        .library(name: "Bitcoin", targets: ["Bitcoin"]),
        .library(name: "BitcoinRPC", targets: ["BitcoinRPC"]),
        .library(name: "BitcoinTransport", targets: ["BitcoinTransport"]),
        .library(name: "BitcoinBlockchain", targets: ["BitcoinBlockchain"]),
        .library(name: "BitcoinWallet", targets: ["BitcoinWallet"]),
        .library(name: "BitcoinBase", targets: ["BitcoinBase"]),
        .library(name: "BitcoinCrypto", targets: ["BitcoinCrypto"]),
        .executable(name: "bcnode", targets: ["BitcoinNode"]),
        .executable(name: "bcutil", targets: ["BitcoinUtility"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-bitcoin/secp256k1", from: "0.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.0.0"),
    ],
    targets: [
        // Exposed libraries
        .target(name: "Bitcoin",
            dependencies: ["BitcoinRPC", "BitcoinTransport", "BitcoinBlockchain", "BitcoinWallet", "BitcoinBase", "BitcoinCrypto"],
            path: "src/bitcoin"),
        .target(name: "BitcoinRPC", dependencies: ["BitcoinTransport", "BitcoinBlockchain", "JSONRPC"], path: "src/bitcoin-rpc"),
        .target(
            name: "BitcoinTransport",
            dependencies: ["BitcoinBlockchain", "BitcoinBase", "BitcoinCrypto",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")],
            path: "src/bitcoin-transport"),
        .target(
            name: "BitcoinBlockchain",
            dependencies: ["BitcoinBase", "BitcoinCrypto",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")],
            path: "src/bitcoin-blockchain"),
        .target(name: "BitcoinWallet", dependencies: ["BitcoinBase", "BitcoinCrypto"], path: "src/bitcoin-wallet"),
        .target(name: "BitcoinBase", dependencies: ["BitcoinCrypto"], path: "src/bitcoin-base"),
        .target(name: "BitcoinCrypto", dependencies: ["ECCHelper",
                .product(name: "Crypto", package: "swift-crypto")],
            path: "src/bitcoin-crypto"),

        // Internal libraries
        .target(
            name: "NIOJSONRPC",
            dependencies: [
                "JSONRPC",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio")],
            path: "src/nio-json-rpc"),
        .target(name: "JSONRPC", path: "src/json-rpc"),
        .target(name: "ECCHelper", dependencies: [.product(name: "LibSECP256k1", package: "secp256k1")], path: "src/ecc-helper"),

        // Tests
        .testTarget(name: "BitcoinTests", dependencies: ["Bitcoin"], path: "test/bitcoin"),
        .testTarget(name: "BitcoinRPCTests", dependencies: ["BitcoinRPC"], path: "test/bitcoin-rpc"),
        .testTarget(name: "BitcoinTransportTests", dependencies: ["BitcoinTransport", "BitcoinWallet"], path: "test/bitcoin-transport"),
        .testTarget(name: "BitcoinBlockchainTests", dependencies: ["BitcoinBlockchain"], path: "test/bitcoin-blockchain"),
        .testTarget(name: "BitcoinWalletTests", dependencies: ["BitcoinWallet"], path: "test/bitcoin-wallet"),
        .testTarget(name: "BitcoinCryptoTests", dependencies: ["BitcoinCrypto"], path: "test/bitcoin-crypto"),
        .testTarget(name: "BitcoinBaseTests", dependencies: ["BitcoinBase"], path: "test/bitcoin-base",
            resources: [.copy("data")]),

        // Plugins
        .plugin(
            name: "GenerateContributors",
            capability: .command(
                intent: .custom(
                    verb: "generate-contributors",
                    description: "Generates the CONTRIBUTORS.txt file based on Git logs"),
                permissions: [
                    .writeToPackageDirectory(reason: "This command write the new CONTRIBUTORS.txt to the source root.")
                ]
            ),
            path: "plugin/generate-contributors"
        ),

        // Executables
        .executableTarget(
            name: "BitcoinNode", dependencies: [
                "BitcoinRPC", "BitcoinTransport", "BitcoinBlockchain", "BitcoinBase", "BitcoinCrypto", "NIOJSONRPC", "JSONRPC",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOExtras", package: "swift-nio-extras")],
            path: "src/bitcoin-node"),
        .executableTarget(
            name: "BitcoinUtility", dependencies: [
                "BitcoinRPC", "BitcoinTransport", "BitcoinBlockchain", "BitcoinWallet", "BitcoinBase", "BitcoinCrypto", "NIOJSONRPC", "JSONRPC",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio")],
            path: "src/bitcoin-utility")
    ]
)
