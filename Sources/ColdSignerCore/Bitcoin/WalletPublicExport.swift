import CryptoKit
import ColdSignerPSBT
import Foundation

public enum WalletPublicExport {
    public static func originAccountKey(profile: WalletProfile) -> String {
        let origin = profile.accountPath
            .replacingOccurrences(of: "m/", with: "")
            .replacingOccurrences(of: "'", with: "h")
        return "[\(profile.fingerprint.uppercased())/\(origin)]\(profile.accountExtendedPublicKey)"
    }

    public static func bip84Slip132AccountKey(profile: WalletProfile) throws -> String {
        try Base58Check.reencodeExtendedPublicKey(
            profile.accountExtendedPublicKey,
            network: profile.network
        )
    }
}

private enum Base58Check {
    private static let alphabet = Array(
        "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".utf8
    )
    private static let reverseAlphabet: [UInt8: Int] = Dictionary(
        uniqueKeysWithValues: alphabet.enumerated().map { ($0.element, $0.offset) }
    )

    static func reencodeExtendedPublicKey(
        _ value: String,
        network: WalletProfile.Network
    ) throws -> String {
        let decoded = try decode(value)
        guard decoded.count == 82 else {
            throw ColdSignerError.invalidWalletDescriptor
        }
        let payload = Data(decoded.prefix(78))
        guard Data(decoded.suffix(4)) == checksum(payload) else {
            throw ColdSignerError.invalidWalletDescriptor
        }

        let expectedVersion: [UInt8]
        let replacementVersion: [UInt8]
        switch network {
        case .bitcoin:
            expectedVersion = [0x04, 0x88, 0xb2, 0x1e]
            replacementVersion = [0x04, 0xb2, 0x47, 0x46]
        case .testnet, .signet:
            expectedVersion = [0x04, 0x35, 0x87, 0xcf]
            replacementVersion = [0x04, 0x5f, 0x1c, 0xf6]
        }
        guard Array(payload.prefix(4)) == expectedVersion else {
            throw ColdSignerError.invalidWalletDescriptor
        }

        var converted = Data(replacementVersion)
        converted.append(payload.dropFirst(4))
        converted.append(checksum(converted))
        return encode(converted)
    }

    private static func checksum(_ data: Data) -> Data {
        let first = Data(SHA256.hash(data: data))
        return Data(SHA256.hash(data: first)).prefix(4)
    }

    private static func decode(_ value: String) throws -> [UInt8] {
        guard !value.isEmpty else { throw ColdSignerError.invalidWalletDescriptor }
        let characters = Array(value.utf8)
        var decoded: [UInt8] = []
        decoded.reserveCapacity(82)

        for character in characters {
            guard let digit = reverseAlphabet[character] else {
                throw ColdSignerError.invalidWalletDescriptor
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

        let leadingZeroes = characters.prefix { $0 == alphabet[0] }.count
        if leadingZeroes > 0 {
            decoded.insert(contentsOf: repeatElement(0, count: leadingZeroes), at: 0)
        }
        return decoded
    }

    private static func encode(_ data: Data) -> String {
        guard !data.isEmpty else { return "" }
        var digits: [UInt8] = []
        digits.reserveCapacity(data.count * 2)

        for byte in data {
            var carry = Int(byte)
            for offset in digits.indices.reversed() {
                carry += Int(digits[offset]) << 8
                digits[offset] = UInt8(carry % 58)
                carry /= 58
            }
            while carry > 0 {
                digits.insert(UInt8(carry % 58), at: 0)
                carry /= 58
            }
        }

        let leadingZeroes = data.prefix { $0 == 0 }.count
        var encoded = [UInt8](repeating: alphabet[0], count: leadingZeroes)
        encoded.append(contentsOf: digits.map { alphabet[Int($0)] })
        return String(decoding: encoded, as: UTF8.self)
    }
}
