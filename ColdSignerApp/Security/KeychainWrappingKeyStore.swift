import ColdSignerCore
import Foundation
import Security

struct KeychainWrappingKeyStore {
    private let service = "org.coldsigner.seed-wrapping-key.v1"
    private let account = "primary-wallet"

    func create() throws -> Data {
        var keyData = Data(count: AESGCMSeedCipher.keyByteCount)
        let randomStatus = keyData.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, bytes.count, bytes.baseAddress!)
        }
        guard randomStatus == errSecSuccess else {
            throw ColdSignerError.secureStorageUnavailable
        }

        var accessError: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            .userPresence,
            &accessError
        ) else {
            throw ColdSignerError.secureStorageUnavailable
        }

        var query = baseQuery
        query[kSecAttrAccessControl] = accessControl
        query[kSecValueData] = keyData

        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else {
            throw ColdSignerError.secureStorageFailure
        }
        return keyData
    }

    func read(localizedReason: String) throws -> Data {
        var query = baseQuery
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        query[kSecUseOperationPrompt] = localizedReason

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let keyData = result as? Data, keyData.count == AESGCMSeedCipher.keyByteCount else {
                throw ColdSignerError.secureStorageFailure
            }
            return keyData
        case errSecUserCanceled:
            throw ColdSignerError.operationCancelled
        case errSecAuthFailed, errSecInteractionNotAllowed:
            throw ColdSignerError.ownerAuthenticationFailed
        case errSecItemNotFound:
            throw ColdSignerError.walletNotFound
        default:
            throw ColdSignerError.secureStorageFailure
        }
    }

    func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ColdSignerError.secureStorageFailure
        }
    }

    private var baseQuery: [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: kCFBooleanFalse as Any,
        ]
    }
}
