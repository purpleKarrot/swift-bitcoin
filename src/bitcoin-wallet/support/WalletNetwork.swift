import Foundation

public enum WalletNetwork: CaseIterable, Sendable {
    case main, test, regtest

    /// Bech32 human readable part (prefix).
    var bech32HRP: String {
        switch self {
        case .main: "bc"
        case .test: "tb"
        case .regtest: "bcrt"
        }
    }
}
