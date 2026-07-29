import ColdSignerCore
import Foundation

@MainActor
final class OnboardingModel: ObservableObject {
    enum Step: Equatable {
        case welcome
        case readiness
        case setupChoice
        case createOptions
        case seedDisplay
        case backupVerification
        case restoreOptions
        case restoreEntry(Int)
        case walletConfirmation
    }

    @Published var step: Step = .welcome
    @Published var selectedNetwork: WalletProfile.Network = .testnet
    @Published private(set) var pendingSetup: WalletSetup?
    @Published private(set) var backupChallenge: BackupChallenge?
    @Published var errorMessage: String?
    @Published var isWorking = false

    private let vault: any WalletVault
    private let deriver: any WalletDeriving
    private let authenticator = DeviceOwnerAuthenticator()

    init(vault: any WalletVault, deriver: any WalletDeriving = BDKWalletDeriver()) {
        self.vault = vault
        self.deriver = deriver
    }

    func continueFromReadiness() {
        guard !isWorking else {
            errorMessage = "正在完成上一项安全操作，请稍候。"
            return
        }
        do {
            try authenticator.requireAvailability()
            errorMessage = nil
            step = .setupChoice
        } catch let error as ColdSignerError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = ColdSignerError.ownerAuthenticationUnavailable.errorDescription
        }
    }

    func createWallet(wordCount: Int) {
        do {
            pendingSetup = try deriver.generate(
                wordCount: wordCount,
                network: selectedNetwork
            )
            backupChallenge = nil
            errorMessage = nil
            step = .seedDisplay
        } catch let error as ColdSignerError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = ColdSignerError.walletDerivationFailed.errorDescription
        }
    }

    func beginBackupVerification() {
        guard let setup = pendingSetup else { return }
        do {
            backupChallenge = try BackupChallenge(wordCount: setup.mnemonic.wordCount)
            errorMessage = nil
            step = .backupVerification
        } catch let error as ColdSignerError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = ColdSignerError.secureStorageFailure.errorDescription
        }
    }

    func verifyBackup(answers: [Int: String]) -> Bool {
        guard
            let setup = pendingSetup,
            let challenge = backupChallenge,
            challenge.verifies(answers, mnemonic: setup.mnemonic)
        else {
            errorMessage = "备份校验失败。请逐字检查纸质备份后重试。"
            return false
        }
        errorMessage = nil
        step = .walletConfirmation
        return true
    }

    func restoreWallet(words: [String]) {
        do {
            pendingSetup = try deriver.restore(
                words: words,
                network: selectedNetwork
            )
            backupChallenge = nil
            errorMessage = nil
            step = .walletConfirmation
        } catch let error as ColdSignerError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = ColdSignerError.invalidMnemonic.errorDescription
        }
    }

    func activate(onComplete: @escaping (WalletProfile) -> Void) async {
        guard let setup = pendingSetup else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            try await vault.store(setup)
            let profile = setup.profile
            pendingSetup = nil
            backupChallenge = nil
            errorMessage = nil
            onComplete(profile)
        } catch let error as ColdSignerError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = ColdSignerError.secureStorageFailure.errorDescription
        }
    }

    func abandonSensitiveFlow() {
        pendingSetup = nil
        backupChallenge = nil
        errorMessage = nil
        step = .setupChoice
    }

    func protectForBackground() {
        pendingSetup = nil
        backupChallenge = nil
        errorMessage = nil
        step = .welcome
    }
}
