import ColdSignerCore
import ColdSignerTransport
import Foundation
import XCTest
@testable import ColdSigner

@MainActor
final class PSBTScannerModelTests: XCTestCase {
    func testMixedOpticalFormatsRequireExplicitRestart() throws {
        var psbt = Data([0x70, 0x73, 0x62, 0x74, 0xff])
        psbt.append(Data(repeating: 0x42, count: 512))
        let ur = try PSBTUREncoder(psbt: psbt, maximumFragmentLength: 40)
        let bbqr = try PSBTBBQREncoder(psbt: psbt, maximumFragmentLength: 64)
        let model = PSBTScannerModel(
            profile: .placeholder,
            vault: NoopWalletVault()
        )

        model.receive(ur.nextPart())
        XCTAssertEqual(model.transportFormat, .bcUR)
        XCTAssertEqual(model.processedPartCount, 1)

        let firstBBQRPart = bbqr.nextPart()
        model.receive(firstBBQRPart)
        XCTAssertNil(model.transportFormat)
        XCTAssertNotNil(model.errorMessage)

        model.receive(firstBBQRPart)
        XCTAssertNil(model.transportFormat)
        XCTAssertNotNil(model.errorMessage)

        model.restart()
        model.receive(firstBBQRPart)
        XCTAssertEqual(model.transportFormat, .bbqr)
        XCTAssertEqual(model.processedPartCount, 1)
    }
}

private actor NoopWalletVault: WalletVault {
    func storedProfile() async throws -> WalletProfile? { nil }
    func store(_ setup: WalletSetup) async throws {}
    func authenticate(localizedReason: String) async throws {}
    func unlock(localizedReason: String) async throws -> WalletSetup {
        throw ColdSignerError.operationCancelled
    }
    func wipe(localizedReason: String) async throws {}
}
