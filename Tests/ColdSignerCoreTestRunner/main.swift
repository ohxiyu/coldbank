import ColdSignerCore
import Foundation

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

private final class CoreTestRunner {
    private(set) var passed = 0

    func run(_ name: String, _ body: () throws -> Void) throws {
        do {
            try body()
            passed += 1
            print("PASS \(name)")
        } catch {
            throw TestFailure(description: "FAIL \(name): \(error)")
        }
    }

    func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw TestFailure(description: message) }
    }

    func expectColdSignerError(
        _ expected: ColdSignerError,
        operation: () throws -> Void
    ) throws {
        do {
            try operation()
            throw TestFailure(description: "expected \(expected.code), but operation succeeded")
        } catch let actual as ColdSignerError {
            try expect(actual == expected, "expected \(expected.code), got \(actual.code)")
        }
    }
}

private func runCoreTests() throws {
        let runner = CoreTestRunner()
        let words = Array(repeating: "abandon", count: 11) + ["about"]
        let deriver = BDKWalletDeriver()

        try runner.run("official BIP84 vector") {
            let setup = try deriver.restore(words: words, network: .bitcoin)
            try runner.expect(setup.profile.fingerprint == "73C5DA0A", "unexpected fingerprint")
            try runner.expect(
                setup.profile.firstReceiveAddress == "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu",
                "unexpected first address"
            )
            try runner.expect(setup.profile.receiveDescriptor.hasPrefix("wpkh([73c5da0a/84'/0'/0']xpub"), "unexpected descriptor origin")
            try runner.expect(setup.profile.receiveDescriptor.hasSuffix("/0/*)#wc3n3van"), "unexpected descriptor checksum")
            try runner.expect(setup.profile.changeDescriptor.contains("/1/*)"), "missing change branch")
        }

        try runner.run("invalid mnemonic checksum") {
            try runner.expectColdSignerError(.invalidMnemonic) {
                _ = try deriver.restore(words: Array(repeating: "abandon", count: 12), network: .bitcoin)
            }
        }

        try runner.run("mnemonic redaction") {
            let setup = try deriver.restore(words: words, network: .bitcoin)
            try runner.expect(setup.mnemonic.description == "[REDACTED mnemonic: 12 words]", "mnemonic description leaked")
            try runner.expect(!setup.mnemonic.description.contains("abandon"), "mnemonic word leaked")
        }

        try runner.run("stable policy error") {
            let error = ColdSignerError.policyViolation(.missingUTXO)
            try runner.expect(error.code == "POLICY-005", "unexpected policy error code")
            try runner.expect(!error.userMessage.lowercased().contains("psbt="), "error leaked payload")
        }

        try runner.run("sensitive diagnostic redaction") {
            try runner.expect(String(describing: SensitiveValue(kind: .mnemonic)) == "[REDACTED mnemonic]", "mnemonic diagnostic leaked")
            try runner.expect(String(reflecting: SensitiveValue(kind: .psbt)) == "[REDACTED psbt]", "PSBT diagnostic leaked")
        }

        try runner.run("transaction policy bounds") {
            let limits = TransactionPolicyLimits.v0_1
            try runner.expect(limits.maximumPSBTBytes == 2_097_152, "unexpected PSBT byte limit")
            try runner.expect(limits.maximumInputCount == 200, "unexpected input limit")
            try runner.expect(limits.maximumOutputCount == 200, "unexpected output limit")
            try runner.expect(limits.maximumQRFragments == 2_000, "unexpected QR fragment limit")
            try runner.expect(limits.maximumDerivationDepth == 10, "unexpected derivation limit")
        }

        try runner.run("AES-GCM seed round trip") {
            let setup = try deriver.restore(words: words, network: .bitcoin)
            let key = Data(repeating: 0x42, count: AESGCMSeedCipher.keyByteCount)
            let cipher = AESGCMSeedCipher()
            let envelope = try cipher.seal(mnemonic: setup.mnemonic, profile: setup.profile, keyData: key)
            let opened = try cipher.open(envelope: envelope, profile: setup.profile, keyData: key)
            try runner.expect(opened == setup.mnemonic, "decrypted mnemonic differs")
            try runner.expect(!String(decoding: envelope.combinedCiphertext, as: UTF8.self).contains("abandon"), "ciphertext contains plaintext")
        }

        try runner.run("AES-GCM wrong key rejection") {
            let setup = try deriver.restore(words: words, network: .bitcoin)
            let cipher = AESGCMSeedCipher()
            let key = Data(repeating: 0x42, count: AESGCMSeedCipher.keyByteCount)
            let wrongKey = Data(repeating: 0x24, count: AESGCMSeedCipher.keyByteCount)
            let envelope = try cipher.seal(mnemonic: setup.mnemonic, profile: setup.profile, keyData: key)
            try runner.expectColdSignerError(.secureStorageFailure) {
                _ = try cipher.open(envelope: envelope, profile: setup.profile, keyData: wrongKey)
            }
        }

        try runner.run("AES-GCM profile binding") {
            let setup = try deriver.restore(words: words, network: .bitcoin)
            let cipher = AESGCMSeedCipher()
            let key = Data(repeating: 0x42, count: AESGCMSeedCipher.keyByteCount)
            let envelope = try cipher.seal(mnemonic: setup.mnemonic, profile: setup.profile, keyData: key)
            let changed = WalletProfile(
                name: setup.profile.name,
                fingerprint: "00000000",
                network: setup.profile.network,
                receiveDescriptor: setup.profile.receiveDescriptor,
                changeDescriptor: setup.profile.changeDescriptor,
                accountExtendedPublicKey: setup.profile.accountExtendedPublicKey,
                firstReceiveAddress: setup.profile.firstReceiveAddress
            )
            try runner.expectColdSignerError(.secureStorageFailure) {
                _ = try cipher.open(envelope: envelope, profile: changed, keyData: key)
            }
        }

        try runner.run("backup challenge verification") {
            let phrase = try MnemonicPhrase(words: words)
            let challenge = try BackupChallenge(positions: [0, 5, 11], wordCount: 12)
            try runner.expect(challenge.verifies([0: "abandon", 5: "abandon", 11: "about"], mnemonic: phrase), "correct backup rejected")
            try runner.expect(!challenge.verifies([0: "about", 5: "abandon", 11: "about"], mnemonic: phrase), "wrong backup accepted")
        }

        try runner.run("random backup challenge bounds") {
            let challenge = try BackupChallenge(wordCount: 24)
            try runner.expect(challenge.positions.count == 3, "unexpected challenge count")
            try runner.expect(Set(challenge.positions).count == 3, "duplicate challenge positions")
            try runner.expect(challenge.positions.allSatisfy { 0..<24 ~= $0 }, "challenge position out of bounds")
        }

    print("Core test runner passed \(runner.passed) checks.")
}

try runCoreTests()
