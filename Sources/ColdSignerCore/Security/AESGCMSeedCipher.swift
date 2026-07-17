import CryptoKit
import Foundation

public struct AESGCMSeedCipher: Sendable {
    public static let keyByteCount = 32
    public static let currentFormatVersion: UInt8 = 1

    public init() {}

    public func seal(
        mnemonic: MnemonicPhrase,
        profile: WalletProfile,
        keyData: Data
    ) throws -> EncryptedSeedEnvelope {
        guard keyData.count == Self.keyByteCount else {
            throw ColdSignerError.secureStorageFailure
        }

        do {
            var plaintext = Data(mnemonic.unsafeJoinedWords.utf8)
            defer { plaintext.resetBytes(in: 0..<plaintext.count) }
            let box = try AES.GCM.seal(
                plaintext,
                using: SymmetricKey(data: keyData),
                authenticating: authenticatedData(for: profile)
            )
            guard let combined = box.combined else {
                throw ColdSignerError.secureStorageFailure
            }
            return EncryptedSeedEnvelope(
                formatVersion: Self.currentFormatVersion,
                combinedCiphertext: combined
            )
        } catch let error as ColdSignerError {
            throw error
        } catch {
            throw ColdSignerError.secureStorageFailure
        }
    }

    public func open(
        envelope: EncryptedSeedEnvelope,
        profile: WalletProfile,
        keyData: Data
    ) throws -> MnemonicPhrase {
        guard
            envelope.formatVersion == Self.currentFormatVersion,
            keyData.count == Self.keyByteCount,
            envelope.combinedCiphertext.count <= 1_024
        else {
            throw ColdSignerError.secureStorageFailure
        }

        do {
            let box = try AES.GCM.SealedBox(combined: envelope.combinedCiphertext)
            var plaintext = try AES.GCM.open(
                box,
                using: SymmetricKey(data: keyData),
                authenticating: authenticatedData(for: profile)
            )
            defer { plaintext.resetBytes(in: 0..<plaintext.count) }
            guard let joinedWords = String(data: plaintext, encoding: .utf8) else {
                throw ColdSignerError.secureStorageFailure
            }
            return try MnemonicPhrase(words: joinedWords.split(separator: " ").map(String.init))
        } catch {
            throw ColdSignerError.secureStorageFailure
        }
    }

    private func authenticatedData(for profile: WalletProfile) -> Data {
        let fields = [
            "org.coldsigner.seed.v1",
            profile.fingerprint,
            profile.network.rawValue,
            profile.receiveDescriptor,
            profile.changeDescriptor,
            profile.accountExtendedPublicKey,
            profile.firstReceiveAddress,
        ]
        return Data(fields.joined(separator: "\u{0}").utf8)
    }
}
