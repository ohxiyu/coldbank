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
    private let autoLockNanoseconds: UInt64
    private var autoLockTask: Task<Void, Never>?
    private var activeUnlockAttempt: UUID?

    init(
        vault: any WalletVault = IOSWalletVault(),
        autoLockNanoseconds: UInt64 = 120 * 1_000_000_000
    ) {
        self.vault = vault
        self.autoLockNanoseconds = max(autoLockNanoseconds, 1)
    }

    func load() async {
        activeUnlockAttempt = nil
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
        let attempt = UUID()
        activeUnlockAttempt = attempt
        defer {
            if activeUnlockAttempt == attempt {
                activeUnlockAttempt = nil
            }
        }
        do {
            let setup = try await vault.unlock(
                localizedReason: "解锁 ColdSigner 离线签名器"
            )
            guard activeUnlockAttempt == attempt else { return }
            phase = .ready(setup.profile)
            scheduleAutoLock()
        } catch let error as ColdSignerError where error == .operationCancelled {
            return
        } catch let error as ColdSignerError {
            guard activeUnlockAttempt == attempt else { return }
            phase = .failed(error.errorDescription ?? error.userMessage)
        } catch {
            guard activeUnlockAttempt == attempt else { return }
            phase = .failed(ColdSignerError.secureStorageFailure.userMessage)
        }
    }

    func didActivate(profile: WalletProfile, unlocked: Bool = true) {
        activeUnlockAttempt = nil
        if unlocked {
            phase = .ready(profile)
            scheduleAutoLock()
        } else {
            autoLockTask?.cancel()
            phase = .locked(profile)
        }
    }

    func lock() {
        activeUnlockAttempt = nil
        autoLockTask?.cancel()
        guard case .ready(let profile) = phase else { return }
        phase = .locked(profile)
    }

    func recordActivity() {
        guard case .ready = phase else { return }
        scheduleAutoLock()
    }

    func wipe() async -> Bool {
        activeUnlockAttempt = nil
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
        let duration = autoLockNanoseconds
        autoLockTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: duration)
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
    func unlock(localizedReason: String) async throws -> WalletSetup {
        throw ColdSignerError.walletNotFound
    }
    func wipe(localizedReason: String) async throws {}
}
