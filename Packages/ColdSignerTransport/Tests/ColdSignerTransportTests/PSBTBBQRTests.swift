import ColdSignerCore
import Foundation
import XCTest
@testable import ColdSignerTransport

final class PSBTBBQRTests: XCTestCase {
    private let smallPSBT = Data([0x70, 0x73, 0x62, 0x74, 0xff, 0x00])

    func testCanonicalHeaderAndEncodingVectors() throws {
        let hex = try PSBTBBQREncoder(psbt: smallPSBT, encoding: .hex)
        XCTAssertEqual(hex.nextPart(), "B$HP010070736274FF00")
        XCTAssertEqual(try PSBTBBQRDecoder().receive(hex.nextPart()).psbt, smallPSBT)

        let base32 = try PSBTBBQREncoder(psbt: smallPSBT, encoding: .base32)
        XCTAssertEqual(base32.nextPart(), "B$2P0100OBZWE5H7AA")
        XCTAssertEqual(try PSBTBBQRDecoder().receive(base32.nextPart()).psbt, smallPSBT)

        let zlibVector = "B$ZP0100FMUE4KXZZ4AAA"
        XCTAssertEqual(try PSBTBBQRDecoder().receive(zlibVector).psbt, smallPSBT)
    }

    func testMultipartReorderingAndDuplicateFrames() throws {
        var psbt = Data([0x70, 0x73, 0x62, 0x74, 0xff])
        psbt.append(contentsOf: (0..<2_048).map { UInt8($0 % 251) })
        let encoder = try PSBTBBQREncoder(
            psbt: psbt,
            maximumFragmentLength: 96
        )
        XCTAssertFalse(encoder.isSinglePart)
        let frames = (0..<encoder.fragmentCount).map { _ in encoder.nextPart() }
        let decoder = PSBTBBQRDecoder()
        var result: Data?
        for frame in [frames.last!] + Array(frames.reversed()) + [frames.first!] {
            let progress = try decoder.receive(frame)
            if let psbt = progress.psbt {
                result = psbt
                break
            }
        }
        XCTAssertEqual(result, psbt)
    }

    func testRejectsWrongTypeConflictsAndOversizedSeries() throws {
        let decoder = PSBTBBQRDecoder()
        XCTAssertThrowsError(try decoder.receive("B$HT010070736274FF00"))

        XCTAssertFalse(try decoder.receive("B$HP020070736274").isComplete)
        XCTAssertThrowsError(try decoder.receive("B$HP0200AA736274"))

        let limits = URTransportLimits(
            maximumPayloadBytes: 64,
            maximumFragments: 2,
            maximumFragmentCharacters: 128,
            maximumProcessedParts: 4
        )
        XCTAssertThrowsError(
            try PSBTBBQRDecoder(limits: limits).receive("B$HP030070736274FF00")
        ) { error in
            XCTAssertEqual(error as? ColdSignerError, .payloadTooLarge)
        }
    }

    func testRejectsOversizedEncodedAndInflatedPayloads() throws {
        let fiveByteLimit = URTransportLimits(
            maximumPayloadBytes: 5,
            maximumFragments: 2,
            maximumFragmentCharacters: 128,
            maximumProcessedParts: 4
        )
        XCTAssertThrowsError(
            try PSBTBBQRDecoder(limits: fiveByteLimit).receive("B$HP010070736274FF00")
        ) { error in
            XCTAssertEqual(error as? ColdSignerError, .payloadTooLarge)
        }
        XCTAssertThrowsError(
            try PSBTBBQRDecoder(limits: fiveByteLimit).receive("B$ZP0100FMUE4KXZZ4AAA")
        ) { error in
            XCTAssertEqual(error as? ColdSignerError, .payloadTooLarge)
        }
    }

    func testCancellationDropsAllParts() throws {
        var psbt = smallPSBT
        psbt.append(Data(repeating: 0x42, count: 256))
        let encoder = try PSBTBBQREncoder(psbt: psbt, maximumFragmentLength: 64)
        let first = encoder.nextPart()
        let decoder = PSBTBBQRDecoder()
        XCTAssertFalse(try decoder.receive(first).isComplete)
        decoder.cancel()
        let restarted = try decoder.receive(first)
        XCTAssertEqual(restarted.processedPartCount, 1)
        XCTAssertFalse(restarted.isComplete)
    }
}
