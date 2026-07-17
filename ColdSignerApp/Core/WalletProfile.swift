import Foundation

struct WalletProfile: Equatable, Sendable {
    enum Network: String, Equatable, Sendable {
        case bitcoin
        case testnet
        case signet

        var displayName: String {
            switch self {
            case .bitcoin: "Mainnet"
            case .testnet: "Testnet"
            case .signet: "Signet"
            }
        }
    }

    let fingerprint: String
    let network: Network
    let accountPath: String

    static let placeholder = WalletProfile(
        fingerprint: "— — — —",
        network: .testnet,
        accountPath: "m/84'/1'/0'"
    )
}
