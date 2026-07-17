import ColdSignerCore
import Foundation
import URKit

public final class PSBTUREncoder {
    public let fragmentCount: Int
    public let isSinglePart: Bool

    private let encoder: UREncoder

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
        let encoder = UREncoder(
            ur,
            maxFragmentLen: maximumFragmentLength,
            minFragmentLen: 10
        )
        guard encoder.seqLen <= limits.maximumFragments else {
            throw ColdSignerError.payloadTooLarge
        }

        self.encoder = encoder
        fragmentCount = encoder.seqLen
        isSinglePart = encoder.isSinglePart
    }

    public func nextPart() -> String {
        // Uppercase keeps QR content in the denser alphanumeric mode. UR decoding is case-insensitive.
        encoder.nextPart().uppercased()
    }
}
