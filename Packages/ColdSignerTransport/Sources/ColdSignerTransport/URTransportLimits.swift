import ColdSignerCore
import Foundation

public struct URTransportLimits: Equatable, Sendable {
    public let maximumPayloadBytes: Int
    public let maximumFragments: Int
    public let maximumFragmentCharacters: Int
    public let maximumProcessedParts: Int

    public init(policy: TransactionPolicyLimits = .v0_1) {
        maximumPayloadBytes = policy.maximumPSBTBytes
        maximumFragments = policy.maximumQRFragments
        maximumFragmentCharacters = 8_192
        maximumProcessedParts = policy.maximumQRFragments * 4
    }

    public init(
        maximumPayloadBytes: Int,
        maximumFragments: Int,
        maximumFragmentCharacters: Int = 8_192,
        maximumProcessedParts: Int? = nil
    ) {
        self.maximumPayloadBytes = maximumPayloadBytes
        self.maximumFragments = maximumFragments
        self.maximumFragmentCharacters = maximumFragmentCharacters
        self.maximumProcessedParts = maximumProcessedParts ?? maximumFragments * 4
    }
}
