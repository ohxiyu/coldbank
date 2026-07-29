import ColdSignerCore
import XCTest
@testable import ColdSigner

@MainActor
final class AppModelLifecycleTests: XCTestCase {
    func testUnlockAutoLocksAndWipeClearsState() async throws {
        let setup = try referenceSetup()
        let vault = LifecycleTestVault(setup: setup)
        let model = AppModel(
            vault: vault,
            autoLockNanoseconds: 1_000_000
        )

        await model.load()
        XCTAssertEqual(model.phase, .locked(setup.profile))

        await model.unlock()
        XCTAssertEqual(model.phase, .ready(setup.profile))
        for _ in 0..<200 where model.phase != .locked(setup.profile) {
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTAssertEqual(model.phase, .locked(setup.profile))

        await model.unlock()
        let didWipe = await model.wipe()
        XCTAssertTrue(didWipe)
        XCTAssertEqual(model.phase, .needsOnboarding)
        let wasWiped = await vault.wasWiped()
        XCTAssertTrue(wasWiped)
    }

    func testCancelledUnlockDoesNotDowngradeOrLoseProfile() async throws {
        let setup = try referenceSetup()
        let vault = LifecycleTestVault(
            setup: setup,
            unlockError: .operationCancelled
        )
        let model = AppModel(vault: vault)

        await model.load()
        await model.unlock()
        XCTAssertEqual(model.phase, .locked(setup.profile))
    }

    func testActivationCompletedOutsideForegroundStaysLocked() throws {
        let setup = try referenceSetup()
        let model = AppModel(
            vault: LifecycleTestVault(setup: setup)
        )

        model.didActivate(profile: setup.profile, unlocked: false)

        XCTAssertEqual(model.phase, .locked(setup.profile))
    }

    func testBackgroundLockInvalidatesInFlightUnlock() async throws {
        let setup = try referenceSetup()
        let vault = LifecycleTestVault(
            setup: setup,
            unlockDelayNanoseconds: 20_000_000
        )
        let model = AppModel(vault: vault)
        await model.load()

        let unlock = Task { await model.unlock() }
        try await Task.sleep(nanoseconds: 1_000_000)
        model.lock()
        await unlock.value

        XCTAssertEqual(model.phase, .locked(setup.profile))
    }

    private func referenceSetup() throws -> WalletSetup {
        WalletSetup(
            mnemonic: try MnemonicPhrase(
                words: Array(repeating: "abandon", count: 11) + ["about"]
            ),
            profile: .placeholder
        )
    }
}

private actor LifecycleTestVault: WalletVault {
    private let setup: WalletSetup
    private let unlockError: ColdSignerError?
    private let unlockDelayNanoseconds: UInt64
    private var wiped = false

    init(
        setup: WalletSetup,
        unlockError: ColdSignerError? = nil,
        unlockDelayNanoseconds: UInt64 = 0
    ) {
        self.setup = setup
        self.unlockError = unlockError
        self.unlockDelayNanoseconds = unlockDelayNanoseconds
    }

    func storedProfile() async throws -> WalletProfile? {
        wiped ? nil : setup.profile
    }

    func store(_ setup: WalletSetup) async throws {}

    func unlock(localizedReason: String) async throws -> WalletSetup {
        if unlockDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: unlockDelayNanoseconds)
        }
        if let unlockError { throw unlockError }
        return setup
    }

    func wipe(localizedReason: String) async throws {
        wiped = true
    }

    func wasWiped() -> Bool { wiped }
}
