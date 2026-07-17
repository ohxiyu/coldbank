import BitcoinDevKit
import ColdSignerCore
import CryptoKit
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

private func appendUInt32LE(_ value: UInt32, to data: inout Data) {
    data.append(contentsOf: [
        UInt8(value & 0xff),
        UInt8((value >> 8) & 0xff),
        UInt8((value >> 16) & 0xff),
        UInt8((value >> 24) & 0xff),
    ])
}

private func appendUInt64LE(_ value: UInt64, to data: inout Data) {
    for shift in stride(from: 0, through: 56, by: 8) {
        data.append(UInt8((value >> UInt64(shift)) & 0xff))
    }
}

private func appendMapEntry(key: Data, value: Data, to data: inout Data) {
    precondition(key.count < 0xfd && value.count < 0xfd)
    data.append(UInt8(key.count))
    data.append(key)
    data.append(UInt8(value.count))
    data.append(value)
}

private func derivedAccountPublicKey(
    profile: WalletProfile,
    branch: UInt32,
    index: UInt32
) throws -> Data {
    let accountKey = try DescriptorPublicKey.fromString(
        publicKey: profile.accountExtendedPublicKey
    )
    let derived = try accountKey.derive(
        path: DerivationPath(path: "m/\(branch)/\(index)")
    )
    guard let encodedKey = derived.description.split(separator: "]").last else {
        throw TestFailure(description: "missing derived extended public key")
    }
    let decoded = try decodeBase58Check(String(encodedKey))
    guard decoded.count == 78 else {
        throw TestFailure(description: "unexpected extended public key length")
    }
    return Data(decoded.suffix(33))
}

private func decodeBase58Check(_ value: String) throws -> Data {
    let alphabet = Array(
        "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".utf8
    )
    let reverse = Dictionary(
        uniqueKeysWithValues: alphabet.enumerated().map { ($0.element, $0.offset) }
    )
    let characters = Array(value.utf8)
    var decoded: [UInt8] = []
    for character in characters {
        guard let digit = reverse[character] else {
            throw TestFailure(description: "invalid Base58 character")
        }
        var carry = digit
        for offset in decoded.indices.reversed() {
            carry += Int(decoded[offset]) * 58
            decoded[offset] = UInt8(carry & 0xff)
            carry >>= 8
        }
        while carry > 0 {
            decoded.insert(UInt8(carry & 0xff), at: 0)
            carry >>= 8
        }
    }
    decoded.insert(
        contentsOf: repeatElement(0, count: characters.prefix { $0 == alphabet[0] }.count),
        at: 0
    )
    guard decoded.count >= 4 else {
        throw TestFailure(description: "short Base58Check value")
    }
    let payload = Data(decoded.dropLast(4))
    let first = Data(SHA256.hash(data: payload))
    let checksum = Data(SHA256.hash(data: first)).prefix(4)
    guard Data(decoded.suffix(4)) == checksum else {
        throw TestFailure(description: "invalid Base58Check checksum")
    }
    return payload
}

private func publicFixtureURL(_ fileName: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/Public/coldsigner-testnet-c03")
        .appendingPathComponent(fileName)
}

private func loadFixturePSBT(_ fileName: String) throws -> Data {
    let encoded = try String(
        contentsOf: publicFixtureURL(fileName),
        encoding: .utf8
    ).trimmingCharacters(in: .whitespacesAndNewlines)
    guard let decoded = Data(base64Encoded: encoded) else {
        throw TestFailure(description: "invalid Base64 fixture: \(fileName)")
    }
    return decoded
}

private func makeStructuralPSBT(
    sighash: UInt32 = 1,
    duplicateWitnessUTXO: Bool = false,
    includeUTXO: Bool = true,
    psbtVersion: UInt32? = nil
) -> Data {
    let outputScript = Data([0x00, 0x14] + Array(repeating: 0x33, count: 20))

    var transaction = Data()
    appendUInt32LE(2, to: &transaction)
    transaction.append(1)
    transaction.append(Data(repeating: 0x11, count: 32))
    appendUInt32LE(0, to: &transaction)
    transaction.append(0)
    appendUInt32LE(UInt32.max, to: &transaction)
    transaction.append(1)
    appendUInt64LE(1_500, to: &transaction)
    transaction.append(UInt8(outputScript.count))
    transaction.append(outputScript)
    appendUInt32LE(0, to: &transaction)

    var psbt = Data([0x70, 0x73, 0x62, 0x74, 0xff])
    appendMapEntry(key: Data([0x00]), value: transaction, to: &psbt)
    if let psbtVersion {
        var versionData = Data()
        appendUInt32LE(psbtVersion, to: &versionData)
        appendMapEntry(key: Data([0xfb]), value: versionData, to: &psbt)
    }
    psbt.append(0)

    if includeUTXO {
        var witnessUTXO = Data()
        appendUInt64LE(2_000, to: &witnessUTXO)
        witnessUTXO.append(UInt8(outputScript.count))
        witnessUTXO.append(outputScript)
        appendMapEntry(key: Data([0x01]), value: witnessUTXO, to: &psbt)
        if duplicateWitnessUTXO {
            appendMapEntry(key: Data([0x01]), value: witnessUTXO, to: &psbt)
        }
    }

    var sighashData = Data()
    appendUInt32LE(sighash, to: &sighashData)
    appendMapEntry(key: Data([0x03]), value: sighashData, to: &psbt)

    let publicKey = Data([0x02] + Array(repeating: 0x44, count: 32))
    var derivationKey = Data([0x06])
    derivationKey.append(publicKey)
    var derivationValue = Data([0x73, 0xc5, 0xda, 0x0a])
    [
        UInt32(84) | 0x8000_0000,
        UInt32(0) | 0x8000_0000,
        UInt32(0) | 0x8000_0000,
        0,
        0,
    ].forEach { appendUInt32LE($0, to: &derivationValue) }
    appendMapEntry(key: derivationKey, value: derivationValue, to: &psbt)
    psbt.append(0)

    var outputDerivationKey = Data([0x02])
    outputDerivationKey.append(publicKey)
    appendMapEntry(key: outputDerivationKey, value: derivationValue, to: &psbt)
    psbt.append(0)
    return psbt
}

private func makePolicyPSBT(
    profile: WalletProfile,
    inputFingerprint: Data = Data([0x73, 0xc5, 0xda, 0x0a]),
    includeNonWitnessUTXO: Bool = true,
    lockTime: UInt32 = 0
) throws -> Data {
    let network: BitcoinDevKit.Network = profile.network == .bitcoin ? .bitcoin : .testnet
    let networkKind: NetworkKind = profile.network == .bitcoin ? .main : .test
    let coinType: UInt32 = profile.network == .bitcoin ? 0 : 1
    let receiveDescriptor = try Descriptor(
        descriptor: profile.receiveDescriptor,
        networkKind: networkKind
    )
    let changeDescriptor = try Descriptor(
        descriptor: profile.changeDescriptor,
        networkKind: networkKind
    )
    let receiveScript = try receiveDescriptor
        .deriveAddress(index: 0, network: network)
        .scriptPubkey()
        .toBytes()
    let changeScript = try changeDescriptor
        .deriveAddress(index: 0, network: network)
        .scriptPubkey()
        .toBytes()
    let recipientScript = Data([0x00, 0x14] + Array(repeating: 0x55, count: 20))

    var previousTransaction = Data()
    appendUInt32LE(2, to: &previousTransaction)
    previousTransaction.append(1)
    previousTransaction.append(Data(repeating: 0x22, count: 32))
    appendUInt32LE(0, to: &previousTransaction)
    previousTransaction.append(0)
    appendUInt32LE(UInt32.max, to: &previousTransaction)
    previousTransaction.append(1)
    appendUInt64LE(2_000, to: &previousTransaction)
    previousTransaction.append(UInt8(receiveScript.count))
    previousTransaction.append(receiveScript)
    appendUInt32LE(0, to: &previousTransaction)

    let previousTxID = try Transaction(transactionBytes: previousTransaction)
        .computeTxid()
        .description
    var previousTxIDBytes: [UInt8] = []
    previousTxIDBytes.reserveCapacity(32)
    var txIDOffset = previousTxID.startIndex
    while txIDOffset < previousTxID.endIndex {
        let next = previousTxID.index(txIDOffset, offsetBy: 2)
        guard let byte = UInt8(previousTxID[txIDOffset..<next], radix: 16) else {
            throw TestFailure(description: "invalid computed transaction ID")
        }
        previousTxIDBytes.append(byte)
        txIDOffset = next
    }

    let receiveKey = try derivedAccountPublicKey(profile: profile, branch: 0, index: 0)
    let changeKey = try derivedAccountPublicKey(profile: profile, branch: 1, index: 0)

    var transaction = Data()
    appendUInt32LE(2, to: &transaction)
    transaction.append(1)
    transaction.append(contentsOf: previousTxIDBytes.reversed())
    appendUInt32LE(0, to: &transaction)
    transaction.append(0)
    appendUInt32LE(0xffff_fffd, to: &transaction)
    transaction.append(2)
    appendUInt64LE(1_000, to: &transaction)
    transaction.append(UInt8(recipientScript.count))
    transaction.append(recipientScript)
    appendUInt64LE(900, to: &transaction)
    transaction.append(UInt8(changeScript.count))
    transaction.append(changeScript)
    appendUInt32LE(lockTime, to: &transaction)

    var psbt = Data([0x70, 0x73, 0x62, 0x74, 0xff])
    appendMapEntry(key: Data([0x00]), value: transaction, to: &psbt)
    psbt.append(0)

    if includeNonWitnessUTXO {
        appendMapEntry(key: Data([0x00]), value: previousTransaction, to: &psbt)
    }
    var witnessUTXO = Data()
    appendUInt64LE(2_000, to: &witnessUTXO)
    witnessUTXO.append(UInt8(receiveScript.count))
    witnessUTXO.append(receiveScript)
    appendMapEntry(key: Data([0x01]), value: witnessUTXO, to: &psbt)
    var sighashData = Data()
    appendUInt32LE(1, to: &sighashData)
    appendMapEntry(key: Data([0x03]), value: sighashData, to: &psbt)

    var receiveDerivationKey = Data([0x06])
    receiveDerivationKey.append(receiveKey)
    var receiveDerivationValue = inputFingerprint
    [
        UInt32(84) | 0x8000_0000,
        coinType | 0x8000_0000,
        UInt32(0) | 0x8000_0000,
        0,
        0,
    ].forEach { appendUInt32LE($0, to: &receiveDerivationValue) }
    appendMapEntry(
        key: receiveDerivationKey,
        value: receiveDerivationValue,
        to: &psbt
    )
    psbt.append(0)

    psbt.append(0)

    var changeDerivationKey = Data([0x02])
    changeDerivationKey.append(changeKey)
    var changeDerivationValue = Data([0x73, 0xc5, 0xda, 0x0a])
    [
        UInt32(84) | 0x8000_0000,
        coinType | 0x8000_0000,
        UInt32(0) | 0x8000_0000,
        1,
        0,
    ].forEach { appendUInt32LE($0, to: &changeDerivationValue) }
    appendMapEntry(
        key: changeDerivationKey,
        value: changeDerivationValue,
        to: &psbt
    )
    psbt.append(0)
    return psbt
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
            let zpub = try WalletPublicExport.bip84Slip132AccountKey(profile: setup.profile)
            try runner.expect(
                zpub == "zpub6rFR7y4Q2AijBEqTUquhVz398htDFrtymD9xYYfG1m4wAcvPhXNfE3EfH1r1ADqtfSdVCToUG868RvUUkgDKf31mGDtKsAYz2oz2AGutZYs",
                "unexpected BIP84 zpub"
            )
            try runner.expect(
                WalletPublicExport.originAccountKey(profile: setup.profile)
                    == "[73C5DA0A/84h/0h/0h]\(setup.profile.accountExtendedPublicKey)",
                "unexpected origin account key"
            )
            let testnetSetup = try deriver.restore(words: words, network: .testnet)
            let vpub = try WalletPublicExport.bip84Slip132AccountKey(
                profile: testnetSetup.profile
            )
            try runner.expect(vpub.hasPrefix("vpub"), "testnet key was not converted to vpub")
            try runner.expect(
                WalletPublicExport.originAccountKey(profile: testnetSetup.profile)
                    == "[73C5DA0A/84h/1h/0h]\(testnetSetup.profile.accountExtendedPublicKey)",
                "unexpected testnet origin account key"
            )
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

        try runner.run("strict PSBT v0 structure") {
            let structure = try StrictPSBTStructureParser.parse(makeStructuralPSBT())
            try runner.expect(structure.psbtVersion == 0, "unexpected PSBT version")
            try runner.expect(structure.transactionVersion == 2, "unexpected transaction version")
            try runner.expect(structure.transactionInputs.count == 1, "unexpected input count")
            try runner.expect(structure.transactionOutputs.count == 1, "unexpected output count")
            try runner.expect(structure.transactionOutputs[0].valueSatoshis == 1_500, "unexpected output value")
            try runner.expect(structure.inputMaps[0].witnessUTXO?.valueSatoshis == 2_000, "missing witness UTXO")
            try runner.expect(structure.inputMaps[0].derivations[0].fingerprint == "73C5DA0A", "unexpected fingerprint")
            try runner.expect(structure.inputMaps[0].derivations[0].path.count == 5, "unexpected path depth")
        }

        try runner.run("duplicate PSBT keys fail closed") {
            try runner.expectColdSignerError(.duplicatePSBTKey) {
                _ = try StrictPSBTStructureParser.parse(
                    makeStructuralPSBT(duplicateWitnessUTXO: true)
                )
            }
        }

        try runner.run("unsupported PSBT sighash fails closed") {
            try runner.expectColdSignerError(.policyViolation(.unsupportedSighash)) {
                _ = try StrictPSBTStructureParser.parse(makeStructuralPSBT(sighash: 0x81))
            }
        }

        try runner.run("missing PSBT UTXO fails closed") {
            try runner.expectColdSignerError(.policyViolation(.missingUTXO)) {
                _ = try StrictPSBTStructureParser.parse(makeStructuralPSBT(includeUTXO: false))
            }
        }

        try runner.run("PSBT v2 fails closed") {
            try runner.expectColdSignerError(.policyViolation(.unsupportedPSBTVersion)) {
                _ = try StrictPSBTStructureParser.parse(makeStructuralPSBT(psbtVersion: 2))
            }
        }

        try runner.run("strict parser deterministic mutation corpus") {
            let original = makeStructuralPSBT()
            var state: UInt64 = 0x434f_4c44_5349_474e
            for iteration in 0..<512 {
                state = state &* 6_364_136_223_846_793_005 &+ 1
                var candidate = original
                let offset = Int(state % UInt64(candidate.count))
                switch iteration % 4 {
                case 0:
                    candidate[offset] ^= UInt8(truncatingIfNeeded: state >> 24) | 1
                case 1:
                    candidate = Data(candidate.prefix(max(1, offset)))
                case 2:
                    candidate.insert(UInt8(truncatingIfNeeded: state), at: offset)
                default:
                    candidate.append(contentsOf: [0xfd, 0, 0])
                }

                do {
                    _ = try StrictPSBTStructureParser.parse(candidate)
                } catch is ColdSignerError {
                    // Rejection is expected; the property under test is bounded,
                    // deterministic completion without a trap or foreign error.
                } catch {
                    throw TestFailure(description: "mutation produced foreign error: \(error)")
                }
            }
        }

        try runner.run("PSBT review verifies ownership and change") {
            let setup = try deriver.restore(words: words, network: .bitcoin)
            let psbt = try makePolicyPSBT(profile: setup.profile)
            let review = try PSBTPolicyEngine().review(
                psbt: psbt,
                profile: setup.profile
            )
            try runner.expect(review.inputCount == 1, "unexpected review input count")
            try runner.expect(review.outputCount == 2, "unexpected review output count")
            try runner.expect(review.recipients.count == 1, "recipient was hidden")
            try runner.expect(review.change.count == 1, "change was not verified")
            try runner.expect(review.recipients[0].derivationPath == nil, "recipient gained wallet path")
            try runner.expect(
                review.change[0].derivationPath == "m/84'/0'/0'/1/0",
                "unexpected change path"
            )
            try runner.expect(review.outgoingSatoshis == 1_000, "unexpected outgoing amount")
            try runner.expect(review.feeSatoshis == 100, "unexpected fee")
            try runner.expect(review.estimatedFeeRate > 0, "missing fee rate")
            try runner.expect(
                review.warnings.contains(.replaceByFeeEnabled),
                "RBF warning was omitted"
            )
            try runner.expect(
                !review.warnings.contains(.lockTimeEnabled),
                "zero locktime was presented as enabled"
            )
            let lockTimeReview = try PSBTPolicyEngine().review(
                psbt: makePolicyPSBT(profile: setup.profile, lockTime: 840_000),
                profile: setup.profile
            )
            try runner.expect(
                lockTimeReview.warnings.contains(.lockTimeEnabled),
                "nonzero enabled locktime warning was omitted"
            )
            let revalidated = try PSBTPolicyEngine().revalidate(
                psbt: psbt,
                against: review,
                profile: setup.profile
            )
            try runner.expect(
                revalidated == review,
                "unchanged review did not revalidate"
            )
        }

        try runner.run("PSBT review commitment detects mutation") {
            let setup = try deriver.restore(words: words, network: .bitcoin)
            let psbt = try makePolicyPSBT(profile: setup.profile)
            let review = try PSBTPolicyEngine().review(psbt: psbt, profile: setup.profile)
            var changed = psbt
            changed[changed.index(before: changed.endIndex)] ^= 0x01
            try runner.expectColdSignerError(.policyViolation(.reviewCommitmentChanged)) {
                _ = try PSBTPolicyEngine().revalidate(
                    psbt: changed,
                    against: review,
                    profile: setup.profile
                )
            }
        }

        try runner.run("PSBT ownership mismatch fails closed") {
            let setup = try deriver.restore(words: words, network: .bitcoin)
            try runner.expectColdSignerError(.policyViolation(.ownershipNotProven)) {
                _ = try PSBTPolicyEngine().review(
                    psbt: makePolicyPSBT(
                        profile: setup.profile,
                        inputFingerprint: Data([0, 0, 0, 0])
                    ),
                    profile: setup.profile
                )
            }
        }

        try runner.run("PSBT signer creates deterministic partial signature") {
            let setup = try deriver.restore(words: words, network: .bitcoin)
            let psbt = try makePolicyPSBT(profile: setup.profile)
            let review = try PSBTPolicyEngine().review(psbt: psbt, profile: setup.profile)
            let first = try PSBTSigner().sign(
                psbt: psbt,
                reviewedAs: review,
                using: setup
            )
            let second = try PSBTSigner().sign(
                psbt: psbt,
                reviewedAs: review,
                using: setup
            )
            try runner.expect(first.signedInputCount == 1, "owned input was not signed")
            try runner.expect(first.signedPSBT != psbt, "signed PSBT was unchanged")
            try runner.expect(first == second, "signature output was not deterministic")
            let signed = try Psbt(psbtBase64: first.signedPSBT.base64EncodedString())
            try runner.expect(signed.input()[0].partialSigs.count == 1, "missing partial signature")
            try runner.expect(signed.input()[0].finalScriptWitness == nil, "signer finalized input")
            try runner.expect(first.commitment == review.commitment, "review commitment changed")
            try runner.expectColdSignerError(.unsupportedPSBTField) {
                _ = try StrictPSBTStructureParser.parse(first.signedPSBT)
            }
        }

        try runner.run("public testnet C03 fixture matches signer") {
            let setup = try deriver.restore(words: words, network: .testnet)
            let generatedUnsigned = try makePolicyPSBT(profile: setup.profile)
            let fixtureUnsigned = try loadFixturePSBT("unsigned.psbt.base64")
            try runner.expect(
                fixtureUnsigned == generatedUnsigned,
                "checked-in unsigned fixture drifted"
            )
            let review = try PSBTPolicyEngine().review(
                psbt: fixtureUnsigned,
                profile: setup.profile
            )
            try runner.expect(review.network == .testnet, "fixture network drifted")
            try runner.expect(review.outgoingSatoshis == 1_000, "fixture outgoing amount drifted")
            try runner.expect(review.feeSatoshis == 100, "fixture fee drifted")
            try runner.expect(review.change.first?.derivationPath == "m/84'/1'/0'/1/0", "fixture change path drifted")
            try runner.expect(review.warnings == [.replaceByFeeEnabled], "fixture warnings drifted")

            let signed = try PSBTSigner().sign(
                psbt: fixtureUnsigned,
                reviewedAs: review,
                using: setup
            )
            let fixtureSigned = try loadFixturePSBT("signed.psbt.base64")
            try runner.expect(
                signed.signedPSBT == fixtureSigned,
                "checked-in signed fixture drifted"
            )
            _ = try JSONSerialization.jsonObject(
                with: Data(contentsOf: publicFixtureURL("decoded.json"))
            )
        }

        try runner.run("PSBT signer rejects post-review mutation") {
            let setup = try deriver.restore(words: words, network: .bitcoin)
            let psbt = try makePolicyPSBT(profile: setup.profile)
            let review = try PSBTPolicyEngine().review(psbt: psbt, profile: setup.profile)
            var changed = psbt
            changed[changed.index(before: changed.endIndex)] ^= 0x01
            try runner.expectColdSignerError(.policyViolation(.reviewCommitmentChanged)) {
                _ = try PSBTSigner().sign(
                    psbt: changed,
                    reviewedAs: review,
                    using: setup
                )
            }
        }

        try runner.run("PSBT signer rejects wrong seed") {
            let setup = try deriver.restore(words: words, network: .bitcoin)
            let wrong = try deriver.restore(
                words: "legal winner thank year wave sausage worth useful legal winner thank yellow"
                    .split(separator: " ")
                    .map(String.init),
                network: .bitcoin
            )
            let mismatched = WalletSetup(mnemonic: wrong.mnemonic, profile: setup.profile)
            let psbt = try makePolicyPSBT(profile: setup.profile)
            let review = try PSBTPolicyEngine().review(psbt: psbt, profile: setup.profile)
            try runner.expectColdSignerError(.policyViolation(.ownershipNotProven)) {
                _ = try PSBTSigner().sign(
                    psbt: psbt,
                    reviewedAs: review,
                    using: mismatched
                )
            }
        }

        try runner.run("PSBT signer requires non-witness transaction") {
            let setup = try deriver.restore(words: words, network: .bitcoin)
            let psbt = try makePolicyPSBT(
                profile: setup.profile,
                includeNonWitnessUTXO: false
            )
            let review = try PSBTPolicyEngine().review(psbt: psbt, profile: setup.profile)
            try runner.expectColdSignerError(.policyViolation(.missingUTXO)) {
                _ = try PSBTSigner().sign(
                    psbt: psbt,
                    reviewedAs: review,
                    using: setup
                )
            }
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

private func emitPublicInteropFixture() throws {
    let words = Array(repeating: "abandon", count: 11) + ["about"]
    let setup = try BDKWalletDeriver().restore(words: words, network: .testnet)
    let unsigned = try makePolicyPSBT(profile: setup.profile)
    let review = try PSBTPolicyEngine().review(psbt: unsigned, profile: setup.profile)
    let signed = try PSBTSigner().sign(
        psbt: unsigned,
        reviewedAs: review,
        using: setup
    )
    print("UNSIGNED_PSBT_BASE64=\(unsigned.base64EncodedString())")
    print("SIGNED_PSBT_BASE64=\(signed.signedPSBT.base64EncodedString())")
    print("FINGERPRINT=\(setup.profile.fingerprint)")
    print("FIRST_RECEIVE_ADDRESS=\(setup.profile.firstReceiveAddress)")
    print("ORIGIN_ACCOUNT_KEY=\(WalletPublicExport.originAccountKey(profile: setup.profile))")
    print("BIP84_VPUB=\(try WalletPublicExport.bip84Slip132AccountKey(profile: setup.profile))")
    print("RECEIVE_DESCRIPTOR=\(setup.profile.receiveDescriptor)")
    print("CHANGE_DESCRIPTOR=\(setup.profile.changeDescriptor)")
    print("REVIEW_COMMITMENT=\(review.commitment.displayValue)")
    print("RECIPIENT_DESTINATION=\(review.recipients[0].destination)")
    print("CHANGE_DESTINATION=\(review.change[0].destination)")
    print("CHANGE_PATH=\(review.change[0].derivationPath ?? "")")
    print("OUTGOING_SATS=\(review.outgoingSatoshis)")
    print("FEE_SATS=\(review.feeSatoshis)")
    print("ESTIMATED_FEE_RATE=\(review.estimatedFeeRate)")
    print("WARNINGS=\(review.warnings)")
    print("SIGNED_INPUT_COUNT=\(signed.signedInputCount)")
}

if CommandLine.arguments.contains("--emit-public-interop-fixture") {
    try emitPublicInteropFixture()
} else {
    try runCoreTests()
}
