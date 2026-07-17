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
            return try UR(type: type.rawValue, cbor: CBOR.data(psbt))
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

        do {
            let decoded = try CBOR(ur.cbor)
            guard case .data(let psbt) = decoded,
                  decoded.cborEncode == ur.cbor
            else {
                throw ColdSignerError.invalidTransportPayload
            }
            try validatePSBT(psbt, limits: limits)
            return psbt
        } catch let error as ColdSignerError {
            throw error
        } catch {
            throw ColdSignerError.invalidTransportPayload
        }
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
}
