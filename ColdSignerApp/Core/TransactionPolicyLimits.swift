import Foundation

struct TransactionPolicyLimits: Equatable, Sendable {
    let maximumPSBTBytes: Int
    let maximumInputCount: Int
    let maximumOutputCount: Int
    let maximumQRFragments: Int
    let maximumDerivationDepth: Int

    static let v0_1 = TransactionPolicyLimits(
        maximumPSBTBytes: 2 * 1_024 * 1_024,
        maximumInputCount: 200,
        maximumOutputCount: 200,
        maximumQRFragments: 2_000,
        maximumDerivationDepth: 10
    )
}
