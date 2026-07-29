import Foundation


public struct TransactionPolicyLimits: Equatable, Sendable {
    public let maximumPSBTBytes: Int
    public let maximumInputCount: Int
    public let maximumOutputCount: Int
    public let maximumQRFragments: Int
    public let maximumDerivationDepth: Int

    public init(
        maximumPSBTBytes: Int,
        maximumInputCount: Int,
        maximumOutputCount: Int,
        maximumQRFragments: Int,
        maximumDerivationDepth: Int
    ) {
        self.maximumPSBTBytes = maximumPSBTBytes
        self.maximumInputCount = maximumInputCount
        self.maximumOutputCount = maximumOutputCount
        self.maximumQRFragments = maximumQRFragments
        self.maximumDerivationDepth = maximumDerivationDepth
    }

    public static let v0_1 = TransactionPolicyLimits(
        maximumPSBTBytes: 2 * 1_024 * 1_024,
        maximumInputCount: 200,
        maximumOutputCount: 200,
        maximumQRFragments: 2_000,
        maximumDerivationDepth: 10
    )
}
