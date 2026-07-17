import Foundation
import XCTest
@testable import ColdSignerTransport

final class PSBTOpticalSoakTests: XCTestCase {
    func testFiftyVariedOpticalRoundTripsWithCancellation() throws {
        for iteration in 0..<50 {
            var psbt = Data([0x70, 0x73, 0x62, 0x74, 0xff])
            psbt.append(
                contentsOf: (0..<(32 + iteration * 23)).map {
                    UInt8(($0 + iteration * 31) % 251)
                }
            )

            let urEncoder = try PSBTUREncoder(
                psbt: psbt,
                maximumFragmentLength: 80
            )
            let urFrames = (0..<urEncoder.fragmentCount).map { _ in
                urEncoder.nextPart()
            }
            let urDecoder = PSBTURDecoder()
            if urFrames.count > 1, iteration.isMultiple(of: 5) {
                _ = try urDecoder.receive(urFrames[0])
                urDecoder.cancel()
            }
            var urResult: Data?
            for frame in urFrames.reversed() {
                urResult = try urDecoder.receive(frame).psbt ?? urResult
            }
            XCTAssertEqual(urResult, psbt, "BC-UR round \(iteration)")

            let encoding: PSBTBBQREncoding = iteration.isMultiple(of: 2)
                ? .hex
                : .base32
            let bbqrEncoder = try PSBTBBQREncoder(
                psbt: psbt,
                encoding: encoding,
                maximumFragmentLength: 80
            )
            let bbqrFrames = (0..<bbqrEncoder.fragmentCount).map { _ in
                bbqrEncoder.nextPart()
            }
            let bbqrDecoder = PSBTBBQRDecoder()
            if bbqrFrames.count > 1, iteration.isMultiple(of: 5) {
                _ = try bbqrDecoder.receive(bbqrFrames[0])
                bbqrDecoder.cancel()
            }
            var bbqrResult: Data?
            for frame in bbqrFrames.reversed() {
                bbqrResult = try bbqrDecoder.receive(frame).psbt ?? bbqrResult
            }
            XCTAssertEqual(bbqrResult, psbt, "BBQr round \(iteration)")
        }
    }
}
