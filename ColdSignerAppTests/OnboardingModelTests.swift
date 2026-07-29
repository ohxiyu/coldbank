import ColdSignerCore
import XCTest
@testable import ColdSigner

@MainActor
final class OnboardingModelTests: XCTestCase {
    func testCreateUsesTestnetByDefault() throws {
        let model = OnboardingModel(
            vault: PreviewWalletVault(),
            deriver: EchoNetworkDeriver()
        )

        model.createWallet(wordCount: 12)

        XCTAssertEqual(model.pendingSetup?.profile.network, .testnet)
        XCTAssertEqual(model.pendingSetup?.profile.accountPath, "m/84'/1'/0'")
    }

    func testRestoreUsesExplicitMainnetSelection() throws {
        let model = OnboardingModel(
            vault: PreviewWalletVault(),
            deriver: EchoNetworkDeriver()
        )
        model.selectedNetwork = .bitcoin

        model.restoreWallet(
            words: Array(repeating: "abandon", count: 11) + ["about"]
        )

        XCTAssertEqual(model.pendingSetup?.profile.network, .bitcoin)
        XCTAssertEqual(model.pendingSetup?.profile.accountPath, "m/84'/0'/0'")
    }

    func testBackgroundProtectionDiscardsPendingMnemonicAndChallenge() throws {
        let model = OnboardingModel(
            vault: PreviewWalletVault(),
            deriver: EchoNetworkDeriver()
        )
        model.createWallet(wordCount: 12)
        model.beginBackupVerification()
        XCTAssertNotNil(model.pendingSetup)
        XCTAssertNotNil(model.backupChallenge)

        model.protectForBackground()

        XCTAssertNil(model.pendingSetup)
        XCTAssertNil(model.backupChallenge)
        XCTAssertEqual(model.step, .welcome)
    }
}

private struct EchoNetworkDeriver: WalletDeriving {
    func generate(
        wordCount: Int,
        network: WalletProfile.Network
    ) throws -> WalletSetup {
        try setup(wordCount: wordCount, network: network)
    }

    func restore(
        words: [String],
        network: WalletProfile.Network
    ) throws -> WalletSetup {
        try setup(wordCount: words.count, network: network)
    }

    private func setup(
        wordCount: Int,
        network: WalletProfile.Network
    ) throws -> WalletSetup {
        let mnemonicWords = wordCount == 24
            ? Array(repeating: "abandon", count: 23) + ["art"]
            : Array(repeating: "abandon", count: 11) + ["about"]
        return WalletSetup(
            mnemonic: try MnemonicPhrase(words: mnemonicWords),
            profile: WalletProfile(
                name: "Test",
                fingerprint: "73C5DA0A",
                network: network,
                receiveDescriptor: "wpkh(test)",
                changeDescriptor: "wpkh(test)",
                accountExtendedPublicKey: network == .bitcoin ? "xpub-test" : "tpub-test",
                firstReceiveAddress: "test-address"
            )
        )
    }
}
