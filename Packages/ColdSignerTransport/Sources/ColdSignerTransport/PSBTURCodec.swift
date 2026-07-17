import ColdSignerCore
import Foundation
import URKit

public enum PSBTURType: String, CaseIterable, Sendable {
    case cryptoPSBT = "crypto-psbt"
    case psbt = "psbt"

    public static let v0_1ExportDefault: Self = .cryptoPSBT
}

public enum PSBTURCodec {
    private static let psbtMagic = Data([0x70, 0x73, 0x62, 0x74, 0xff])

    public static func encode(
        _ psbt: Data,
        type: PSBTURType = .v0_1ExportDefault,
        limits: URTransportLimits = .init()
    ) throws -> UR {
        try validatePSBT(psbt, limits: limits)

        do {
            return try UR(type: type.rawValue, cbor: encodeCanonicalByteString(psbt))
        } catch {
            throw ColdSignerError.invalidTransportPayload
        }
    }

    public static func decode(
        _ ur: UR,
        limits: URTransportLimits = .init()
    ) throws -> Data {
        guard PSBTURType(rawValue: ur.type) != nil else {
            throw ColdSignerError.invalidTransportPayload
        }

        // A canonical CBOR byte string adds at most nine bytes of length metadata.
        guard ur.cbor.count <= limits.maximumPayloadBytes + 9 else {
            throw ColdSignerError.payloadTooLarge
        }

        let psbt = try decodeCanonicalByteString(ur.cbor)
        try validatePSBT(psbt, limits: limits)
        return psbt
    }

    private static func validatePSBT(
        _ psbt: Data,
        limits: URTransportLimits
    ) throws {
        guard psbt.count <= limits.maximumPayloadBytes else {
            throw ColdSignerError.payloadTooLarge
        }
        guard psbt.starts(with: psbtMagic) else {
            throw ColdSignerError.invalidTransportPayload
        }
    }

    private static func encodeCanonicalByteString(_ value: Data) -> Data {
        var result = Data()
        switch value.count {
        case 0...23:
            result.append(0x40 | UInt8(value.count))
        case 24...0xff:
            result.append(0x58)
            result.append(UInt8(value.count))
        case 0x100...0xffff:
            result.append(0x59)
            result.append(UInt8((value.count >> 8) & 0xff))
            result.append(UInt8(value.count & 0xff))
        default:
            result.append(0x5a)
            result.append(UInt8((value.count >> 24) & 0xff))
            result.append(UInt8((value.count >> 16) & 0xff))
            result.append(UInt8((value.count >> 8) & 0xff))
            result.append(UInt8(value.count & 0xff))
        }
        result.append(value)
        return result
    }

    private static func decodeCanonicalByteString(_ cbor: Data) throws -> Data {
        guard let first = cbor.first, first >> 5 == 2 else {
            throw ColdSignerError.invalidTransportPayload
        }

        let additionalInformation = first & 0x1f
        func byte(at offset: Int) -> UInt8 {
            cbor[cbor.index(cbor.startIndex, offsetBy: offset)]
        }
        let headerLength: Int
        let payloadLength: Int

        switch additionalInformation {
        case 0...23:
            headerLength = 1
            payloadLength = Int(additionalInformation)
        case 24:
            guard cbor.count >= 2, byte(at: 1) >= 24 else {
                throw ColdSignerError.invalidTransportPayload
            }
            headerLength = 2
            payloadLength = Int(byte(at: 1))
        case 25:
            guard cbor.count >= 3 else {
                throw ColdSignerError.invalidTransportPayload
            }
            let length = (Int(byte(at: 1)) << 8) | Int(byte(at: 2))
            guard length > 0xff else {
                throw ColdSignerError.invalidTransportPayload
            }
            headerLength = 3
            payloadLength = length
        case 26:
            guard cbor.count >= 5 else {
                throw ColdSignerError.invalidTransportPayload
            }
            let length = (Int(byte(at: 1)) << 24)
                | (Int(byte(at: 2)) << 16)
                | (Int(byte(at: 3)) << 8)
                | Int(byte(at: 4))
            guard length > 0xffff else {
                throw ColdSignerError.invalidTransportPayload
            }
            headerLength = 5
            payloadLength = length
        default:
            // Indefinite, reserved, and 64-bit lengths cannot be canonical under the v0.1 cap.
            throw ColdSignerError.invalidTransportPayload
        }

        guard payloadLength <= Int.max - headerLength,
              cbor.count == headerLength + payloadLength
        else {
            throw ColdSignerError.invalidTransportPayload
        }
        return cbor.subdata(in: headerLength..<cbor.count)
    }
}
