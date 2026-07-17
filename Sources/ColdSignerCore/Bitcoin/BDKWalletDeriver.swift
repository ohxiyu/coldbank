import BitcoinDevKit
import Foundation

public protocol WalletDeriving: Sendable {
    func generate(wordCount: Int, network: WalletProfile.Network) throws -> WalletSetup
    func restore(words: [String], network: WalletProfile.Network) throws -> WalletSetup
}

public struct WalletSetup: Sendable {
    public let mnemonic: MnemonicPhrase
    public let profile: WalletProfile

    public init(mnemonic: MnemonicPhrase, profile: WalletProfile) {
        self.mnemonic = mnemonic
        self.profile = profile
    }
}

public struct BDKWalletDeriver: WalletDeriving {
    public init() {}

    public func generate(wordCount: Int, network: WalletProfile.Network) throws -> WalletSetup {
        let bdkWordCount: WordCount
        switch wordCount {
        case 12: bdkWordCount = .words12
        case 24: bdkWordCount = .words24
        default: throw ColdSignerError.unsupportedWordCount(wordCount)
        }

        let mnemonic = Mnemonic(wordCount: bdkWordCount)
        return try makeSetup(mnemonic: mnemonic, network: network)
    }

    public func restore(words: [String], network: WalletProfile.Network) throws -> WalletSetup {
        guard words.count == 12 || words.count == 24 else {
            throw ColdSignerError.unsupportedWordCount(words.count)
        }

        do {
            let mnemonic = try Mnemonic.fromString(mnemonic: words.joined(separator: " "))
            return try makeSetup(mnemonic: mnemonic, network: network)
        } catch let error as ColdSignerError {
            throw error
        } catch {
            throw ColdSignerError.invalidMnemonic
        }
    }

    private func makeSetup(mnemonic: Mnemonic, network: WalletProfile.Network) throws -> WalletSetup {
        do {
            let phrase = try MnemonicPhrase(words: mnemonic.description.split(separator: " ").map(String.init))
            let rootKey = DescriptorSecretKey(
                networkKind: network.bdkNetworkKind,
                mnemonic: mnemonic,
                password: nil
            )
            let receiveDescriptor = Descriptor.newBip84(
                secretKey: rootKey,
                keychainKind: .external,
                networkKind: network.bdkNetworkKind
            )
            let changeDescriptor = Descriptor.newBip84(
                secretKey: rootKey,
                keychainKind: .internal,
                networkKind: network.bdkNetworkKind
            )
            try receiveDescriptor.sanityCheck()
            try changeDescriptor.sanityCheck()

            let publicReceive = receiveDescriptor.description
            let publicChange = changeDescriptor.description
            let fingerprint = try Self.extractFingerprint(from: publicReceive)
            let accountKey = try Self.extractAccountKey(from: publicReceive)
            let firstAddress = try receiveDescriptor.deriveAddress(index: 0, network: network.bdkNetwork).description

            return WalletSetup(
                mnemonic: phrase,
                profile: WalletProfile(
                    name: "ColdSigner",
                    fingerprint: fingerprint.uppercased(),
                    network: network,
                    receiveDescriptor: publicReceive,
                    changeDescriptor: publicChange,
                    accountExtendedPublicKey: accountKey,
                    firstReceiveAddress: firstAddress
                )
            )
        } catch let error as ColdSignerError {
            throw error
        } catch {
            throw ColdSignerError.walletDerivationFailed
        }
    }

    static func extractFingerprint(from descriptor: String) throws -> String {
        guard
            let openingBracket = descriptor.firstIndex(of: "["),
            let slash = descriptor[openingBracket...].firstIndex(of: "/")
        else {
            throw ColdSignerError.invalidWalletDescriptor
        }
        let value = descriptor[descriptor.index(after: openingBracket)..<slash]
        guard value.count == 8, value.allSatisfy(\.isHexDigit) else {
            throw ColdSignerError.invalidWalletDescriptor
        }
        return String(value)
    }

    static func extractAccountKey(from descriptor: String) throws -> String {
        guard
            let closingBracket = descriptor.firstIndex(of: "]"),
            let derivationSlash = descriptor[closingBracket...].firstIndex(of: "/")
        else {
            throw ColdSignerError.invalidWalletDescriptor
        }
        let value = descriptor[descriptor.index(after: closingBracket)..<derivationSlash]
        guard value.hasPrefix("xpub") || value.hasPrefix("tpub") else {
            throw ColdSignerError.invalidWalletDescriptor
        }
        return String(value)
    }
}

private extension WalletProfile.Network {
    var bdkNetworkKind: NetworkKind {
        switch self {
        case .bitcoin: .main
        case .testnet, .signet: .test
        }
    }

    var bdkNetwork: BitcoinDevKit.Network {
        switch self {
        case .bitcoin: .bitcoin
        case .testnet: .testnet
        case .signet: .signet
        }
    }
}
