import ColdSignerCore
import Foundation

public struct URTransportLimits: Equatable, Sendable {
    public let maximumPayloadBytes: Int
    public let maximumFragments: Int

    public init(policy: TransactionPolicyLimits = .v0_1) {
        maximumPayloadBytes = policy.maximumPSBTBytes
        maximumFragments = policy.maximumQRFragments
    }
}
