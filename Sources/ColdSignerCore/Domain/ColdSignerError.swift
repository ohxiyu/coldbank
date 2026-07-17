import Foundation

public enum ColdSignerError: Error, Equatable, Sendable {
    case invalidMnemonic
    case unsupportedWordCount(Int)
    case walletDerivationFailed
    case invalidWalletDescriptor
    case ownerAuthenticationUnavailable
    case ownerAuthenticationFailed
    case secureStorageUnavailable
    case secureStorageFailure
    case walletNotFound
    case walletLocked
    case policyViolation(PolicyViolation)
    case invalidTransportPayload
    case payloadTooLarge
    case operationCancelled

    public var code: String {
        switch self {
        case .invalidMnemonic: "KEY-001"
        case .unsupportedWordCount: "KEY-002"
        case .walletDerivationFailed: "KEY-003"
        case .invalidWalletDescriptor: "KEY-004"
        case .ownerAuthenticationUnavailable: "AUTH-001"
        case .ownerAuthenticationFailed: "AUTH-002"
        case .secureStorageUnavailable: "STORE-001"
        case .secureStorageFailure: "STORE-002"
        case .walletNotFound: "STORE-003"
        case .walletLocked: "SESSION-001"
        case .policyViolation(let violation): violation.code
        case .invalidTransportPayload: "UR-001"
        case .payloadTooLarge: "UR-002"
        case .operationCancelled: "FLOW-001"
        }
    }

    public var userMessage: String {
        switch self {
        case .invalidMnemonic:
            "The recovery words or checksum are invalid."
        case .unsupportedWordCount:
            "ColdSigner supports 12-word or 24-word recovery phrases."
        case .walletDerivationFailed:
            "The BIP84 wallet could not be derived."
        case .invalidWalletDescriptor:
            "The wallet descriptor is invalid or incomplete."
        case .ownerAuthenticationUnavailable:
            "Enable an iPhone passcode before creating a signer."
        case .ownerAuthenticationFailed:
            "Device-owner authentication failed. The signer remains locked."
        case .secureStorageUnavailable, .secureStorageFailure:
            "Secure local storage is unavailable. Wallet activation is blocked."
        case .walletNotFound:
            "No local signer wallet was found."
        case .walletLocked:
            "Unlock the signer before continuing."
        case .policyViolation(let violation):
            violation.userMessage
        case .invalidTransportPayload:
            "The scanned QR payload is invalid or unsupported."
        case .payloadTooLarge:
            "The scanned payload exceeds ColdSigner safety limits."
        case .operationCancelled:
            "The operation was cancelled."
        }
    }
}

extension ColdSignerError: LocalizedError {
    public var errorDescription: String? { "\(code): \(userMessage)" }
}

public enum PolicyViolation: Equatable, Sendable {
    case unsupportedPSBTVersion
    case unsupportedScript
    case unsupportedSighash
    case networkMismatch
    case missingUTXO
    case ownershipNotProven
    case feeUnavailable
    case amountOverflow
    case tooManyInputs
    case tooManyOutputs
    case reviewCommitmentChanged

    public var code: String {
        switch self {
        case .unsupportedPSBTVersion: "POLICY-001"
        case .unsupportedScript: "POLICY-002"
        case .unsupportedSighash: "POLICY-003"
        case .networkMismatch: "POLICY-004"
        case .missingUTXO: "POLICY-005"
        case .ownershipNotProven: "POLICY-006"
        case .feeUnavailable: "POLICY-007"
        case .amountOverflow: "POLICY-008"
        case .tooManyInputs: "POLICY-009"
        case .tooManyOutputs: "POLICY-010"
        case .reviewCommitmentChanged: "POLICY-011"
        }
    }

    public var userMessage: String {
        switch self {
        case .unsupportedPSBTVersion: "Only PSBT v0 is supported in this release."
        case .unsupportedScript: "This transaction uses an unsupported Bitcoin script."
        case .unsupportedSighash: "This transaction requests an unsupported signature type."
        case .networkMismatch: "The transaction network does not match this wallet."
        case .missingUTXO: "Input information is incomplete, so the fee cannot be verified."
        case .ownershipNotProven: "ColdSigner cannot prove that an input belongs to this wallet."
        case .feeUnavailable: "The miner fee cannot be calculated. Signing is blocked."
        case .amountOverflow: "Transaction amounts are invalid."
        case .tooManyInputs: "The transaction contains too many inputs."
        case .tooManyOutputs: "The transaction contains too many outputs."
        case .reviewCommitmentChanged: "The transaction changed after review. Scan it again."
        }
    }
}
