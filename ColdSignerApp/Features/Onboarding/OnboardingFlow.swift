import ColdSignerCore
import SwiftUI

struct OnboardingFlow: View {
    @StateObject private var model: OnboardingModel
    let onComplete: (WalletProfile) -> Void

    init(vault: any WalletVault, onComplete: @escaping (WalletProfile) -> Void) {
        _model = StateObject(wrappedValue: OnboardingModel(vault: vault))
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack {
            Group {
                switch model.step {
                case .welcome:
                    WelcomeView { model.step = .readiness }
                case .readiness:
                    ReadinessView(
                        errorMessage: model.errorMessage,
                        onBack: { model.step = .welcome },
                        onContinue: model.continueFromReadiness
                    )
                case .setupChoice:
                    SetupChoiceView(
                        network: $model.selectedNetwork,
                        create: { model.step = .createOptions },
                        restore: { model.step = .restoreOptions }
                    )
                case .createOptions:
                    CreateOptionsView(
                        onBack: { model.step = .setupChoice },
                        create: model.createWallet
                    )
                case .seedDisplay:
                    if let setup = model.pendingSetup {
                        SeedDisplayView(
                            mnemonic: setup.mnemonic,
                            onCancel: model.abandonSensitiveFlow,
                            onContinue: model.beginBackupVerification
                        )
                    }
                case .backupVerification:
                    if let challenge = model.backupChallenge {
                        BackupVerificationView(
                            challenge: challenge,
                            errorMessage: model.errorMessage,
                            onCancel: model.abandonSensitiveFlow,
                            verify: model.verifyBackup
                        )
                    }
                case .restoreOptions:
                    RestoreOptionsView(
                        onBack: { model.step = .setupChoice },
                        choose: { model.step = .restoreEntry($0) }
                    )
                case .restoreEntry(let wordCount):
                    SeedRestoreView(
                        wordCount: wordCount,
                        errorMessage: model.errorMessage,
                        onCancel: model.abandonSensitiveFlow,
                        restore: model.restoreWallet
                    )
                case .walletConfirmation:
                    if let setup = model.pendingSetup {
                        WalletConfirmationView(
                            profile: setup.profile,
                            isWorking: model.isWorking,
                            errorMessage: model.errorMessage,
                            onCancel: model.abandonSensitiveFlow,
                            activate: {
                                await model.activate(onComplete: onComplete)
                            }
                        )
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: model.step)
        }
    }
}
