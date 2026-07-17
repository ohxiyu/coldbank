import XCTest
@testable import ColdSignerTransport

final class PSBTOpticalFormatTests: XCTestCase {
    func testDetectsOnlySupportedCaseRules() {
        XCTAssertEqual(PSBTOpticalFormat.detect("ur:crypto-psbt/example"), .bcUR)
        XCTAssertEqual(PSBTOpticalFormat.detect("UR:CRYPTO-PSBT/EXAMPLE"), .bcUR)
        XCTAssertEqual(PSBTOpticalFormat.detect("B$HP010070736274FF00"), .bbqr)
        XCTAssertNil(PSBTOpticalFormat.detect("b$hp010070736274ff00"))
        XCTAssertNil(PSBTOpticalFormat.detect("bitcoin:bc1qexample"))
    }
}
