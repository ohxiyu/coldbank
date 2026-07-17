import ColdSignerCore
import Foundation
import URKit

public final class PSBTUREncoder {
    private enum Storage {
        case single(String)
        case multipart(UREncoder)
    }

    public let fragmentCount: Int
    public let isSinglePart: Bool

    private let storage: Storage

    public init(
        psbt: Data,
        type: PSBTURType = .v0_1ExportDefault,
        maximumFragmentLength: Int = 250,
        limits: URTransportLimits = .init()
    ) throws {
        guard (10...4_096).contains(maximumFragmentLength) else {
            throw ColdSignerError.invalidTransportPayload
        }

        let ur = try PSBTURCodec.encode(psbt, type: type, limits: limits)
        if ur.cbor.count <= maximumFragmentLength {
            storage = .single(ur.qrString)
            fragmentCount = 1
            isSinglePart = true
            return
        }

        let encoder = UREncoder(
            ur,
            maxFragmentLen: maximumFragmentLength,
            minFragmentLen: 10
        )
        guard encoder.seqLen <= limits.maximumFragments else {
            throw ColdSignerError.payloadTooLarge
        }

        storage = .multipart(encoder)
        fragmentCount = encoder.seqLen
        isSinglePart = false
    }

    public func nextPart() -> String {
        // Uppercase keeps QR content in the denser alphanumeric mode. UR decoding is case-insensitive.
        switch storage {
        case .single(let value):
            return value
        case .multipart(let encoder):
            return encoder.nextPart().uppercased()
        }
    }
}
