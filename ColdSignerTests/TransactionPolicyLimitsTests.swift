import XCTest
@testable import ColdSigner

final class TransactionPolicyLimitsTests: XCTestCase {
    func testV01LimitsRemainBounded() {
        let limits = TransactionPolicyLimits.v0_1

        XCTAssertEqual(limits.maximumPSBTBytes, 2_097_152)
        XCTAssertEqual(limits.maximumInputCount, 200)
        XCTAssertEqual(limits.maximumOutputCount, 200)
        XCTAssertEqual(limits.maximumQRFragments, 2_000)
        XCTAssertEqual(limits.maximumDerivationDepth, 10)
    }
}
