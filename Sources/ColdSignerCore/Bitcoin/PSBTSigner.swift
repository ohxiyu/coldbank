import BitcoinDevKit
import Foundation

public struct PSBTSigningResult: Equatable, Sendable {
    public let signedPSBT: Data
    public let signedInputCount: Int
    public let commitment: PSBTReviewCommitment

    public init(
        signedPSBT: Data,
        signedInputCount: Int,
        commitment: PSBTReviewCommitment
    ) {
        self.signedPSBT = signedPSBT
        self.signedInputCount = signedInputCount
        self.commitment = commitment
    }
}

public struct PSBTSigner: Sendable {
    private let policyEngine = PSBTPolicyEngine()

    public init() {}

    public func sign(
        psbt data: Data,
        reviewedAs priorReview: PSBTReview,
        using setup: WalletSetup,
        limits: TransactionPolicyLimits = .v0_1
    ) throws -> PSBTSigningResult {
        do {
            let review = try policyEngine.revalidate(
                psbt: data,
                against: priorReview,
                profile: setup.profile,
                limits: limits
            )
            let unsignedStructure = try StrictPSBTStructureParser.parse(
                data,
                limits: limits
            )

            // BDK deliberately requires the complete previous transaction unless
            // trustWitnessUtxo is enabled. ColdSigner never weakens that default.
            guard unsignedStructure.inputMaps.allSatisfy({
                $0.hasNonWitnessUTXO && $0.witnessUTXO != nil
            }) else {
                throw ColdSignerError.policyViolation(.missingUTXO)
            }

            let mnemonic = try setup.mnemonic.withUnsafeWords { words in
                try Mnemonic.fromString(mnemonic: words.joined(separator: " "))
            }
            let rootKey = DescriptorSecretKey(
                networkKind: setup.profile.network.bdkNetworkKind,
                mnemonic: mnemonic,
                password: nil
            )
            let receiveDescriptor = Descriptor.newBip84(
                secretKey: rootKey,
                keychainKind: .external,
                networkKind: setup.profile.network.bdkNetworkKind
            )
            let changeDescriptor = Descriptor.newBip84(
                secretKey: rootKey,
                keychainKind: .internal,
                networkKind: setup.profile.network.bdkNetworkKind
            )
            let persister = try Persister.newInMemory()
            let wallet = try Wallet(
                descriptor: receiveDescriptor,
                changeDescriptor: changeDescriptor,
                network: setup.profile.network.bdkNetwork,
                persister: persister
            )
            guard wallet.publicDescriptor(keychain: .external) == setup.profile.receiveDescriptor,
                  wallet.publicDescriptor(keychain: .internal) == setup.profile.changeDescriptor
            else {
                throw ColdSignerError.policyViolation(.ownershipNotProven)
            }

            let psbt = try Psbt(psbtBase64: data.base64EncodedString())
            let originalInputs = psbt.input()
            guard originalInputs.allSatisfy({
                $0.partialSigs.isEmpty
                    && $0.finalScriptSig == nil
                    && $0.finalScriptWitness == nil
            }) else {
                throw ColdSignerError.unsupportedPSBTField
            }

            _ = try wallet.sign(
                psbt: psbt,
                signOptions: SignOptions(
                    trustWitnessUtxo: false,
                    assumeHeight: nil,
                    allowAllSighashes: false,
                    tryFinalize: false,
                    signWithTapInternalKey: false,
                    allowGrinding: true
                )
            )

            guard let signedData = Data(base64Encoded: psbt.serialize()) else {
                throw ColdSignerError.invalidSignedPSBT
            }
            let signedStructure = try StrictPSBTStructureParser.parseSignedResult(
                signedData,
                limits: limits
            )
            let signedInputs = psbt.input()
            let signedInputCount = signedInputs.filter { !$0.partialSigs.isEmpty }.count

            guard signedStructure.unsignedTransaction == unsignedStructure.unsignedTransaction,
                  signedStructure.transactionInputs == unsignedStructure.transactionInputs,
                  signedStructure.transactionOutputs == unsignedStructure.transactionOutputs,
                  signedStructure.inputMaps.count == unsignedStructure.inputMaps.count,
                  zip(signedStructure.inputMaps, unsignedStructure.inputMaps).allSatisfy({
                      signed, unsigned in
                      signed.hasNonWitnessUTXO == unsigned.hasNonWitnessUTXO
                          && signed.nonWitnessUTXOCommitment == unsigned.nonWitnessUTXOCommitment
                          && signed.witnessUTXO == unsigned.witnessUTXO
                          && signed.sighashType == unsigned.sighashType
                          && signed.derivations == unsigned.derivations
                  }),
                  signedStructure.outputMaps == unsignedStructure.outputMaps,
                  signedInputCount == unsignedStructure.transactionInputs.count,
                  signedInputs.allSatisfy({
                      $0.partialSigs.count == 1
                          && $0.finalScriptSig == nil
                          && $0.finalScriptWitness == nil
                  }),
                  signedStructure.inputMaps.allSatisfy({ $0.partialSignatureCount == 1 }),
                  (try? psbt.fee()) == review.feeSatoshis
            else {
                throw ColdSignerError.invalidSignedPSBT
            }

            return PSBTSigningResult(
                signedPSBT: signedData,
                signedInputCount: signedInputCount,
                commitment: review.commitment
            )
        } catch let error as ColdSignerError {
            throw error
        } catch {
            throw ColdSignerError.signingFailed
        }
    }
}
