import ColdSignerCore
import XCTest
@testable import ColdSigner

final class AppSmokeTests: XCTestCase {
    func testCorePackageIsLinked() {
        XCTAssertEqual(WalletProfile.placeholder.network, .testnet)
    }
}
