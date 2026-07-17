import BitcoinDevKit
import CryptoKit
import Foundation

public struct PSBTReviewCommitment: Equatable, Sendable {
    public let digest: Data

    public var displayValue: String {
        digest.prefix(6).map { String(format: "%02x", $0) }.joined()
    }
}

public enum PSBTReviewOutputClassification: Equatable, Sendable {
    case recipient
    case verifiedChange
    case walletReceive
}

public struct PSBTReviewOutput: Equatable, Sendable {
    public let index: Int
    public let valueSatoshis: UInt64
    public let destination: String
    public let scriptDigest: String
    public let classification: PSBTReviewOutputClassification
}

public enum PSBTReviewWarning: Equatable, Hashable, Sendable {
    case replaceByFeeEnabled
    case lockTimeEnabled
    case walletReceiveOutput
    case nonAddressOutput
}

public struct PSBTReview: Equatable, Sendable {
    public let network: WalletProfile.Network
    public let recipients: [PSBTReviewOutput]
    public let change: [PSBTReviewOutput]
    public let totalInputSatoshis: UInt64
    public let totalOutputSatoshis: UInt64
    public let outgoingSatoshis: UInt64
    public let feeSatoshis: UInt64
    public let estimatedSignedVBytes: UInt64
    public let estimatedFeeRate: Double
    public let inputCount: Int
    public let outputCount: Int
    public let transactionVersion: Int32
    public let lockTime: UInt32
    public let warnings: [PSBTReviewWarning]
    public let commitment: PSBTReviewCommitment
}

public struct PSBTPolicyEngine: Sendable {
    public init() {}

    public func review(
        psbt data: Data,
        profile: WalletProfile,
        limits: TransactionPolicyLimits = .v0_1
    ) throws -> PSBTReview {
        do {
            let structure = try StrictPSBTStructureParser.parse(data, limits: limits)
            let psbt = try Psbt(psbtBase64: data.base64EncodedString())
            let bdkInputs = psbt.input()
            let bdkOutputs = psbt.output()
            guard bdkInputs.count == structure.transactionInputs.count,
                  bdkOutputs.count == structure.transactionOutputs.count
            else {
                throw ColdSignerError.invalidPSBT
            }

            let receiveDescriptor = try Descriptor(
                descriptor: profile.receiveDescriptor,
                networkKind: profile.network.bdkNetworkKind
            )
            let changeDescriptor = try Descriptor(
                descriptor: profile.changeDescriptor,
                networkKind: profile.network.bdkNetworkKind
            )
            var totalInput: UInt64 = 0
            for index in bdkInputs.indices {
                let utxo = try resolvedUTXO(
                    bdkInput: bdkInputs[index],
                    transactionInput: structure.transactionInputs[index]
                )
                guard isP2WPKH(utxo.scriptPubkey.toBytes()) else {
                    throw ColdSignerError.policyViolation(.unsupportedScript)
                }
                let ownership = try verifiedOwnership(
                    claims: structure.inputMaps[index].derivations,
                    profile: profile,
                    receiveDescriptor: receiveDescriptor,
                    changeDescriptor: changeDescriptor
                )
                guard ownership.script.toBytes() == utxo.scriptPubkey.toBytes() else {
                    throw ColdSignerError.policyViolation(.ownershipNotProven)
                }

                let (newTotal, overflow) = totalInput.addingReportingOverflow(utxo.value.toSat())
                guard !overflow else {
                    throw ColdSignerError.policyViolation(.amountOverflow)
                }
                totalInput = newTotal
            }

            let transaction = try Transaction(
                transactionBytes: structure.unsignedTransaction
            )
            let transactionOutputs = transaction.output()
            guard transactionOutputs.count == structure.transactionOutputs.count else {
                throw ColdSignerError.invalidPSBT
            }

            var recipients: [PSBTReviewOutput] = []
            var change: [PSBTReviewOutput] = []
            var warnings = Set<PSBTReviewWarning>()
            var totalOutput: UInt64 = 0
            var outgoing: UInt64 = 0

            for index in transactionOutputs.indices {
                let bdkOutput = transactionOutputs[index]
                let structureOutput = structure.transactionOutputs[index]
                let script = bdkOutput.scriptPubkey.toBytes()
                guard bdkOutput.value.toSat() == structureOutput.valueSatoshis,
                      script == structureOutput.scriptPubKey
                else {
                    throw ColdSignerError.invalidPSBT
                }

                let classification = try classifyOutput(
                    claims: structure.outputMaps[index].derivations,
                    script: bdkOutput.scriptPubkey,
                    profile: profile,
                    receiveDescriptor: receiveDescriptor,
                    changeDescriptor: changeDescriptor
                )
                let address = try? Address.fromScript(
                    script: bdkOutput.scriptPubkey,
                    network: profile.network.bdkNetwork
                ).description
                if address == nil { warnings.insert(.nonAddressOutput) }
                if classification == .walletReceive {
                    warnings.insert(.walletReceiveOutput)
                }

                let output = PSBTReviewOutput(
                    index: index,
                    valueSatoshis: structureOutput.valueSatoshis,
                    destination: address ?? "Script \(digestPrefix(script))",
                    scriptDigest: digestPrefix(script),
                    classification: classification
                )
                let (newTotal, totalOverflow) = totalOutput.addingReportingOverflow(
                    structureOutput.valueSatoshis
                )
                guard !totalOverflow else {
                    throw ColdSignerError.policyViolation(.amountOverflow)
                }
                totalOutput = newTotal

                if classification == .verifiedChange {
                    change.append(output)
                } else {
                    let (newOutgoing, outgoingOverflow) = outgoing.addingReportingOverflow(
                        structureOutput.valueSatoshis
                    )
                    guard !outgoingOverflow else {
                        throw ColdSignerError.policyViolation(.amountOverflow)
                    }
                    outgoing = newOutgoing
                    recipients.append(output)
                }
            }

            guard totalInput >= totalOutput else {
                throw ColdSignerError.policyViolation(.feeUnavailable)
            }
            let fee = totalInput - totalOutput
            guard (try? psbt.fee()) == fee else {
                throw ColdSignerError.policyViolation(.feeUnavailable)
            }

            if transaction.isExplicitlyRbf() { warnings.insert(.replaceByFeeEnabled) }
            if transaction.isLockTimeEnabled() { warnings.insert(.lockTimeEnabled) }

            let estimatedSignedVBytes = estimatedP2WPKHSignedVBytes(
                baseTransactionBytes: structure.unsignedTransaction.count,
                inputCount: structure.transactionInputs.count
            )
            return PSBTReview(
                network: profile.network,
                recipients: recipients,
                change: change,
                totalInputSatoshis: totalInput,
                totalOutputSatoshis: totalOutput,
                outgoingSatoshis: outgoing,
                feeSatoshis: fee,
                estimatedSignedVBytes: estimatedSignedVBytes,
                estimatedFeeRate: Double(fee) / Double(estimatedSignedVBytes),
                inputCount: structure.transactionInputs.count,
                outputCount: structure.transactionOutputs.count,
                transactionVersion: structure.transactionVersion,
                lockTime: structure.lockTime,
                warnings: warnings.sorted(by: warningOrder),
                commitment: PSBTReviewCommitment(
                    digest: Data(SHA256.hash(data: data))
                )
            )
        } catch let error as ColdSignerError {
            throw error
        } catch {
            throw ColdSignerError.invalidPSBT
        }
    }

    public func revalidate(
        psbt data: Data,
        against priorReview: PSBTReview,
        profile: WalletProfile,
        limits: TransactionPolicyLimits = .v0_1
    ) throws -> PSBTReview {
        let currentCommitment = PSBTReviewCommitment(
            digest: Data(SHA256.hash(data: data))
        )
        guard currentCommitment == priorReview.commitment else {
            throw ColdSignerError.policyViolation(.reviewCommitmentChanged)
        }
        let currentReview = try review(psbt: data, profile: profile, limits: limits)
        guard currentReview == priorReview else {
            throw ColdSignerError.policyViolation(.reviewCommitmentChanged)
        }
        return currentReview
    }

    private func resolvedUTXO(
        bdkInput: Input,
        transactionInput: PSBTTransactionInputStructure
    ) throws -> TxOut {
        var nonWitnessOutput: TxOut?
        if let transaction = bdkInput.nonWitnessUtxo {
            let expectedTxid = transactionInput.previousTransactionID
                .reversed()
                .map { String(format: "%02x", $0) }
                .joined()
            guard transaction.computeTxid().description.lowercased() == expectedTxid,
                  Int(transactionInput.outputIndex) < transaction.output().count
            else {
                throw ColdSignerError.invalidPSBT
            }
            nonWitnessOutput = transaction.output()[Int(transactionInput.outputIndex)]
        }

        if let witnessOutput = bdkInput.witnessUtxo,
           let nonWitnessOutput {
            guard witnessOutput.value.toSat() == nonWitnessOutput.value.toSat(),
                  witnessOutput.scriptPubkey.toBytes() == nonWitnessOutput.scriptPubkey.toBytes()
            else {
                throw ColdSignerError.invalidPSBT
            }
        }
        guard let output = bdkInput.witnessUtxo ?? nonWitnessOutput else {
            throw ColdSignerError.policyViolation(.missingUTXO)
        }
        return output
    }

    private func verifiedOwnership(
        claims: [PSBTDerivationClaim],
        profile: WalletProfile,
        receiveDescriptor: Descriptor,
        changeDescriptor: Descriptor
    ) throws -> (branch: UInt32, index: UInt32, script: Script) {
        let candidates = claims.filter {
            $0.fingerprint.uppercased() == profile.fingerprint.uppercased()
        }
        guard candidates.count == 1 else {
            throw ColdSignerError.policyViolation(.ownershipNotProven)
        }
        return try verifiedClaim(
            candidates[0],
            profile: profile,
            receiveDescriptor: receiveDescriptor,
            changeDescriptor: changeDescriptor
        )
    }

    private func verifiedClaim(
        _ claim: PSBTDerivationClaim,
        profile: WalletProfile,
        receiveDescriptor: Descriptor,
        changeDescriptor: Descriptor
    ) throws -> (branch: UInt32, index: UInt32, script: Script) {
        let expectedCoinType: UInt32 = profile.network == .bitcoin ? 0 : 1
        guard claim.path.count == 5,
              claim.path[0] == (84 | 0x8000_0000),
              claim.path[1] == (expectedCoinType | 0x8000_0000),
              claim.path[2] == 0x8000_0000,
              claim.path[3] <= 1,
              claim.path[4] < 0x8000_0000
        else {
            throw ColdSignerError.policyViolation(.ownershipNotProven)
        }

        let branch = claim.path[3]
        let index = claim.path[4]
        let claimedKey = claim.compressedPublicKey
            .map { String(format: "%02x", $0) }
            .joined()

        let descriptor = branch == 0 ? receiveDescriptor : changeDescriptor
        let address = try descriptor.deriveAddress(
            index: index,
            network: profile.network.bdkNetwork
        )
        let claimedKeyAddress = try Descriptor.newWpkh(pk: claimedKey)
            .deriveAddress(index: 0, network: profile.network.bdkNetwork)
        guard claimedKeyAddress.scriptPubkey().toBytes() == address.scriptPubkey().toBytes() else {
            throw ColdSignerError.policyViolation(.ownershipNotProven)
        }
        return (branch, index, address.scriptPubkey())
    }

    private func classifyOutput(
        claims: [PSBTDerivationClaim],
        script: Script,
        profile: WalletProfile,
        receiveDescriptor: Descriptor,
        changeDescriptor: Descriptor
    ) throws -> PSBTReviewOutputClassification {
        let candidates = claims.filter {
            $0.fingerprint.uppercased() == profile.fingerprint.uppercased()
        }
        guard !candidates.isEmpty else { return .recipient }
        guard candidates.count == 1 else {
            throw ColdSignerError.policyViolation(.ownershipNotProven)
        }
        let ownership = try verifiedClaim(
            candidates[0],
            profile: profile,
            receiveDescriptor: receiveDescriptor,
            changeDescriptor: changeDescriptor
        )
        guard ownership.script.toBytes() == script.toBytes() else {
            throw ColdSignerError.policyViolation(.ownershipNotProven)
        }
        return ownership.branch == 1 ? .verifiedChange : .walletReceive
    }

    private func isP2WPKH(_ script: Data) -> Bool {
        script.count == 22 && script.first == 0x00 && script.dropFirst().first == 0x14
    }

    private func digestPrefix(_ data: Data) -> String {
        Data(SHA256.hash(data: data))
            .prefix(6)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func estimatedP2WPKHSignedVBytes(
        baseTransactionBytes: Int,
        inputCount: Int
    ) -> UInt64 {
        let weight = UInt64(baseTransactionBytes) * 4
            + 2
            + UInt64(inputCount) * 109
        return (weight + 3) / 4
    }

    private func warningOrder(_ lhs: PSBTReviewWarning, _ rhs: PSBTReviewWarning) -> Bool {
        warningRank(lhs) < warningRank(rhs)
    }

    private func warningRank(_ warning: PSBTReviewWarning) -> Int {
        switch warning {
        case .replaceByFeeEnabled: 0
        case .lockTimeEnabled: 1
        case .walletReceiveOutput: 2
        case .nonAddressOutput: 3
        }
    }
}
