import Foundation

public protocol WalletVault: Sendable {
    func storedProfile() async throws -> WalletProfile?
    func store(_ setup: WalletSetup) async throws
    func unlock(localizedReason: String) async throws -> WalletSetup
    func wipe(localizedReason: String) async throws
}

public struct EncryptedSeedEnvelope: Codable, Equatable, Sendable {
    public let formatVersion: UInt8
    public let combinedCiphertext: Data

    public init(formatVersion: UInt8, combinedCiphertext: Data) {
        self.formatVersion = formatVersion
        self.combinedCiphertext = combinedCiphertext
    }
}

public struct WalletVaultRecord: Codable, Equatable, Sendable {
    public let formatVersion: UInt8
    public let profile: WalletProfile
    public let encryptedSeed: EncryptedSeedEnvelope

    public init(formatVersion: UInt8, profile: WalletProfile, encryptedSeed: EncryptedSeedEnvelope) {
        self.formatVersion = formatVersion
        self.profile = profile
        self.encryptedSeed = encryptedSeed
    }
}
