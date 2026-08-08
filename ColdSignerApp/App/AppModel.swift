import ColdSignerCore
import Foundation

@MainActor
final class AppModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case needsOnboarding
        case locked(WalletProfile)
        case ready(WalletProfile)
        case failed(String)
    }

    @Published private(set) var phase: Phase = .loading
    let vault: any WalletVault
    private var autoLockTask: Task<Void, Never>?

    init(vault: any WalletVault = IOSWalletVault()) {
        self.vault = vault
    }

    func load() async {
        autoLockTask?.cancel()
        phase = .loading
        do {
            if let profile = try await vault.storedProfile() {
                phase = .locked(profile)
            } else {
                phase = .needsOnboarding
            }
        } catch let error as ColdSignerError {
            phase = .failed(error.errorDescription ?? error.userMessage)
        } catch {
            phase = .failed(ColdSignerError.secureStorageFailure.userMessage)
        }
    }

    func unlock() async {
        guard case .locked(let profile) = phase else { return }
        do {
            // Owner authentication only; the seed stays encrypted until the
            // signing flow itself calls vault.unlock.
            try await vault.authenticate(
                localizedReason: "解锁 ColdSigner 离线签名器"
            )
            phase = .ready(profile)
            scheduleAutoLock()
        } catch let error as ColdSignerError where error == .operationCancelled {
            return
        } catch let error as ColdSignerError {
            phase = .failed(error.errorDescription ?? error.userMessage)
        } catch {
            phase = .failed(ColdSignerError.secureStorageFailure.userMessage)
        }
    }

    func didActivate(profile: WalletProfile) {
        phase = .ready(profile)
        scheduleAutoLock()
    }

    func lock() {
        guard case .ready(let profile) = phase else { return }
        autoLockTask?.cancel()
        phase = .locked(profile)
    }

    func recordActivity() {
        guard case .ready = phase else { return }
        scheduleAutoLock()
    }

    func wipe() async -> Bool {
        do {
            try await vault.wipe(localizedReason: "确认永久删除这台 iPhone 上的签名器")
            autoLockTask?.cancel()
            phase = .needsOnboarding
            return true
        } catch let error as ColdSignerError where error == .operationCancelled {
            return false
        } catch let error as ColdSignerError {
            phase = .failed(error.errorDescription ?? error.userMessage)
            return false
        } catch {
            phase = .failed(ColdSignerError.secureStorageFailure.userMessage)
            return false
        }
    }

    private func scheduleAutoLock() {
        autoLockTask?.cancel()
        autoLockTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 120 * 1_000_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.lock()
        }
    }
}

actor PreviewWalletVault: WalletVault {
    func storedProfile() async throws -> WalletProfile? { nil }
    func store(_ setup: WalletSetup) async throws {}
    func authenticate(localizedReason: String) async throws {}
    func unlock(localizedReason: String) async throws -> WalletSetup {
        throw ColdSignerError.walletNotFound
    }
    func wipe(localizedReason: String) async throws {}
}
