import Foundation

public struct WalletProfile: Codable, Equatable, Sendable {
    public enum Network: String, Codable, CaseIterable, Equatable, Sendable {
        case bitcoin
        case testnet
        case signet

        public var displayName: String {
            switch self {
            case .bitcoin: "Mainnet"
            case .testnet: "Testnet"
            case .signet: "Signet"
            }
        }

        public var accountPath: String {
            switch self {
            case .bitcoin: "m/84'/0'/0'"
            case .testnet, .signet: "m/84'/1'/0'"
            }
        }
    }

    public let name: String
    public let fingerprint: String
    public let network: Network
    public let receiveDescriptor: String
    public let changeDescriptor: String
    public let accountExtendedPublicKey: String
    public let firstReceiveAddress: String

    public init(
        name: String,
        fingerprint: String,
        network: Network,
        receiveDescriptor: String,
        changeDescriptor: String,
        accountExtendedPublicKey: String,
        firstReceiveAddress: String
    ) {
        self.name = name
        self.fingerprint = fingerprint
        self.network = network
        self.receiveDescriptor = receiveDescriptor
        self.changeDescriptor = changeDescriptor
        self.accountExtendedPublicKey = accountExtendedPublicKey
        self.firstReceiveAddress = firstReceiveAddress
    }

    public var accountPath: String { network.accountPath }

    public static let placeholder = WalletProfile(
        name: "ColdSigner",
        fingerprint: "— — — —",
        network: .testnet,
        receiveDescriptor: "",
        changeDescriptor: "",
        accountExtendedPublicKey: "",
        firstReceiveAddress: ""
    )
}
