import ColdSignerCore
import Foundation

actor IOSWalletVault: WalletVault {
    private let cipher = AESGCMSeedCipher()
    private let keyStore = KeychainWrappingKeyStore()
    private let authenticator = DeviceOwnerAuthenticator()
    private let fileManager = FileManager.default
    private let recordURL: URL

    init(baseDirectory: URL? = nil) {
        if let baseDirectory {
            recordURL = baseDirectory.appendingPathComponent("wallet.vault", isDirectory: false)
        } else {
            let applicationSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
            recordURL = applicationSupport
                .appendingPathComponent("ColdSigner", isDirectory: true)
                .appendingPathComponent("wallet.vault", isDirectory: false)
        }
    }

    func storedProfile() async throws -> WalletProfile? {
        guard fileManager.fileExists(atPath: recordURL.path) else { return nil }
        return try readRecord().profile
    }

    func store(_ setup: WalletSetup) async throws {
        try authenticator.requireAvailability()
        guard !fileManager.fileExists(atPath: recordURL.path) else {
            throw ColdSignerError.secureStorageFailure
        }

        try await authenticator.authenticate(
            localizedReason: "保护并激活 ColdSigner 离线签名器"
        )
        // Keychain items can survive app reinstallation. With no vault record,
        // an old wrapping key is unusable and must not block a clean setup.
        try keyStore.delete()

        var keyData = try keyStore.create()
        defer { keyData.resetBytes(in: 0..<keyData.count) }
        do {
            let envelope = try cipher.seal(
                mnemonic: setup.mnemonic,
                profile: setup.profile,
                keyData: keyData
            )
            let record = WalletVaultRecord(
                formatVersion: 1,
                profile: setup.profile,
                encryptedSeed: envelope
            )
            try writeRecord(record)
        } catch {
            try? keyStore.delete()
            throw ColdSignerError.secureStorageFailure
        }
    }

    func authenticate(localizedReason: String) async throws {
        guard fileManager.fileExists(atPath: recordURL.path) else {
            throw ColdSignerError.walletNotFound
        }
        try await authenticator.authenticate(localizedReason: localizedReason)
    }

    func unlock(localizedReason: String) async throws -> WalletSetup {
        let record = try readRecord()
        var keyData = try keyStore.read(localizedReason: localizedReason)
        defer { keyData.resetBytes(in: 0..<keyData.count) }
        let mnemonic = try cipher.open(
            envelope: record.encryptedSeed,
            profile: record.profile,
            keyData: keyData
        )
        return WalletSetup(mnemonic: mnemonic, profile: record.profile)
    }

    func wipe(localizedReason: String) async throws {
        guard fileManager.fileExists(atPath: recordURL.path) else {
            try keyStore.delete()
            return
        }

        try await authenticator.authenticate(localizedReason: localizedReason)
        do {
            try fileManager.removeItem(at: recordURL)
            try keyStore.delete()
        } catch {
            throw ColdSignerError.secureStorageFailure
        }
    }

    private func readRecord() throws -> WalletVaultRecord {
        do {
            let data = try Data(contentsOf: recordURL, options: [.mappedIfSafe])
            guard data.count <= 16_384 else {
                throw ColdSignerError.secureStorageFailure
            }
            let record = try JSONDecoder().decode(WalletVaultRecord.self, from: data)
            guard record.formatVersion == 1 else {
                throw ColdSignerError.secureStorageFailure
            }
            return record
        } catch let error as ColdSignerError {
            throw error
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            throw ColdSignerError.walletNotFound
        } catch {
            throw ColdSignerError.secureStorageFailure
        }
    }

    private func writeRecord(_ record: WalletVaultRecord) throws {
        let directory = recordURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )

        var directoryValues = URLResourceValues()
        directoryValues.isExcludedFromBackup = true
        var mutableDirectory = directory
        try mutableDirectory.setResourceValues(directoryValues)

        let encoded = try JSONEncoder().encode(record)
        try encoded.write(to: recordURL, options: [.atomic, .completeFileProtection])

        var fileValues = URLResourceValues()
        fileValues.isExcludedFromBackup = true
        var mutableRecordURL = recordURL
        try mutableRecordURL.setResourceValues(fileValues)
    }
}
