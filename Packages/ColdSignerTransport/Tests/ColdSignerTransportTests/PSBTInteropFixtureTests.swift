import Foundation
import XCTest
@testable import ColdSignerTransport

final class PSBTInteropFixtureTests: XCTestCase {
    func testCheckedInC03OpticalPartsMatchPSBTs() throws {
        for prefix in ["unsigned", "signed"] {
            let psbt = try loadPSBT("\(prefix).psbt.base64")
            let expectedUR = try loadLines("\(prefix)-bcur.txt")
            let expectedBBQR = try loadLines("\(prefix)-bbqr.txt")

            let urEncoder = try PSBTUREncoder(
                psbt: psbt,
                maximumFragmentLength: 100
            )
            let generatedUR = (0..<urEncoder.fragmentCount).map { _ in
                urEncoder.nextPart()
            }
            XCTAssertEqual(generatedUR, expectedUR)

            let urDecoder = PSBTURDecoder()
            var urResult: Data?
            for frame in expectedUR.reversed() {
                urResult = try urDecoder.receive(frame).psbt ?? urResult
            }
            XCTAssertEqual(urResult, psbt)

            let bbqrEncoder = try PSBTBBQREncoder(
                psbt: psbt,
                encoding: .hex,
                maximumFragmentLength: 100
            )
            let generatedBBQR = (0..<bbqrEncoder.fragmentCount).map { _ in
                bbqrEncoder.nextPart()
            }
            XCTAssertEqual(generatedBBQR, expectedBBQR)

            let bbqrDecoder = PSBTBBQRDecoder()
            var bbqrResult: Data?
            for frame in [expectedBBQR.last!] + Array(expectedBBQR.reversed()) {
                if let decoded = try bbqrDecoder.receive(frame).psbt {
                    bbqrResult = decoded
                    break
                }
            }
            XCTAssertEqual(bbqrResult, psbt)
        }
    }

    private func loadPSBT(_ fileName: String) throws -> Data {
        let encoded = try String(
            contentsOf: fixtureDirectory.appendingPathComponent(fileName),
            encoding: .utf8
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return try XCTUnwrap(Data(base64Encoded: encoded))
    }

    private func loadLines(_ fileName: String) throws -> [String] {
        try String(
            contentsOf: fixtureDirectory.appendingPathComponent(fileName),
            encoding: .utf8
        )
        .split(whereSeparator: \.isNewline)
        .map(String.init)
    }

    private var fixtureDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Public/coldsigner-testnet-c03")
    }
}
