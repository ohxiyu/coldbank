import ColdSignerCore
import Foundation
import LocalAuthentication
import Security

/// Stores the seed data-encryption key wrapped by a Secure Enclave P-256 key,
/// so the Keychain never holds the DEK in extractable form. A device without a
/// usable Secure Enclave must block wallet activation instead of falling back
/// to a software-only key.
struct KeychainWrappingKeyStore {
    private let service = "org.coldsigner.seed-wrapping-key.v2"
    private let legacyService = "org.coldsigner.seed-wrapping-key.v1"
    private let account = "primary-wallet"
    private let enclaveKeyTag = Data("org.coldsigner.seed-wrapping-enclave.v1".utf8)
    private static let wrapAlgorithm: SecKeyAlgorithm =
        .eciesEncryptionCofactorVariableIVX963SHA256AESGCM

    func create() throws -> Data {
        var keyData = Data(count: AESGCMSeedCipher.keyByteCount)
        let randomStatus = keyData.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, bytes.count, bytes.baseAddress!)
        }
        guard randomStatus == errSecSuccess else {
            throw ColdSignerError.secureStorageUnavailable
        }

        let enclaveKey = try makeEnclaveKey()
        guard let publicKey = SecKeyCopyPublicKey(enclaveKey),
              SecKeyIsAlgorithmSupported(publicKey, .encrypt, Self.wrapAlgorithm)
        else {
            try? deleteEnclaveKey()
            throw ColdSignerError.secureStorageUnavailable
        }

        var wrapError: Unmanaged<CFError>?
        guard let wrappedKey = SecKeyCreateEncryptedData(
            publicKey,
            Self.wrapAlgorithm,
            keyData as CFData,
            &wrapError
        ) else {
            try? deleteEnclaveKey()
            throw ColdSignerError.secureStorageFailure
        }

        var query = wrappedKeyQuery(service: service)
        query[kSecAttrAccessible] = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        query[kSecValueData] = wrappedKey as Data

        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else {
            try? deleteEnclaveKey()
            throw ColdSignerError.secureStorageFailure
        }
        return keyData
    }

    func read(localizedReason: String) throws -> Data {
        var query = wrappedKeyQuery(service: service)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            break
        case errSecItemNotFound:
            throw ColdSignerError.walletNotFound
        default:
            throw ColdSignerError.secureStorageFailure
        }
        guard let wrappedKey = result as? Data else {
            throw ColdSignerError.secureStorageFailure
        }

        let enclaveKey = try copyEnclaveKey(localizedReason: localizedReason)
        var unwrapError: Unmanaged<CFError>?
        guard let keyData = SecKeyCreateDecryptedData(
            enclaveKey,
            Self.wrapAlgorithm,
            wrappedKey as CFData,
            &unwrapError
        ) as Data? else {
            throw mappedUnwrapError(unwrapError)
        }
        guard keyData.count == AESGCMSeedCipher.keyByteCount else {
            throw ColdSignerError.secureStorageFailure
        }
        return keyData
    }

    func delete() throws {
        for service in [service, legacyService] {
            let status = SecItemDelete(wrappedKeyQuery(service: service) as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw ColdSignerError.secureStorageFailure
            }
        }
        try deleteEnclaveKey()
    }

    private func makeEnclaveKey() throws -> SecKey {
        try deleteEnclaveKey()

        var accessError: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            [.privateKeyUsage, .userPresence],
            &accessError
        ) else {
            throw ColdSignerError.secureStorageUnavailable
        }

        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits: 256,
            kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs: [
                kSecAttrIsPermanent: true,
                kSecAttrApplicationTag: enclaveKeyTag,
                kSecAttrAccessControl: accessControl,
            ] as [CFString: Any],
        ]

        var createError: Unmanaged<CFError>?
        guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &createError) else {
            throw ColdSignerError.secureStorageUnavailable
        }
        return key
    }

    private func copyEnclaveKey(localizedReason: String) throws -> SecKey {
        let authenticationContext = LAContext()
        authenticationContext.localizedReason = localizedReason

        let query: [CFString: Any] = [
            kSecClass: kSecClassKey,
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrApplicationTag: enclaveKeyTag,
            kSecReturnRef: true,
            kSecUseAuthenticationContext: authenticationContext,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            break
        case errSecItemNotFound:
            throw ColdSignerError.walletNotFound
        case errSecUserCanceled:
            throw ColdSignerError.operationCancelled
        case errSecAuthFailed, errSecInteractionNotAllowed:
            throw ColdSignerError.ownerAuthenticationFailed
        default:
            throw ColdSignerError.secureStorageFailure
        }
        guard let reference = result, CFGetTypeID(reference) == SecKeyGetTypeID() else {
            throw ColdSignerError.secureStorageFailure
        }
        return (reference as! SecKey)
    }

    private func deleteEnclaveKey() throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassKey,
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrApplicationTag: enclaveKeyTag,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ColdSignerError.secureStorageFailure
        }
    }

    private func mappedUnwrapError(_ error: Unmanaged<CFError>?) -> ColdSignerError {
        guard let error = error?.takeRetainedValue() else {
            return .secureStorageFailure
        }
        let nsError = error as Error as NSError
        if nsError.domain == LAError.errorDomain {
            switch LAError.Code(rawValue: nsError.code) {
            case .userCancel, .systemCancel, .appCancel:
                return .operationCancelled
            default:
                return .ownerAuthenticationFailed
            }
        }
        if nsError.domain == NSOSStatusErrorDomain {
            switch OSStatus(nsError.code) {
            case errSecUserCanceled:
                return .operationCancelled
            case errSecAuthFailed, errSecInteractionNotAllowed:
                return .ownerAuthenticationFailed
            default:
                return .secureStorageFailure
            }
        }
        return .secureStorageFailure
    }

    private func wrappedKeyQuery(service: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: kCFBooleanFalse as Any,
        ]
    }
}
