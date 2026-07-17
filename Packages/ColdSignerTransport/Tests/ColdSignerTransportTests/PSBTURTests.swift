import ColdSignerCore
import Foundation
import URKit
import XCTest
@testable import ColdSignerTransport

final class PSBTURTests: XCTestCase {
    private let smallPSBT = Data([0x70, 0x73, 0x62, 0x74, 0xff, 0x00])

    func testSinglePartRoundTripForBothAcceptedTypes() throws {
        for type in PSBTURType.allCases {
            let encoder = try PSBTUREncoder(psbt: smallPSBT, type: type)
            XCTAssertTrue(encoder.isSinglePart)

            let progress = try PSBTURDecoder().receive(encoder.nextPart())
            XCTAssertTrue(progress.isComplete)
            XCTAssertEqual(progress.psbt, smallPSBT)
        }
    }

    func testCanonicalCBORByteStringVectors() throws {
        let ur = try PSBTURCodec.encode(smallPSBT)
        XCTAssertEqual(ur.type, "crypto-psbt")
        XCTAssertEqual(
            ur.cbor,
            Data([0x46, 0x70, 0x73, 0x62, 0x74, 0xff, 0x00])
        )

        for payloadLength in [23, 24, 255, 256, 65_535, 65_536] {
            var psbt = Data([0x70, 0x73, 0x62, 0x74, 0xff])
            psbt.append(Data(repeating: 0x5a, count: payloadLength - psbt.count))
            let encoded = try PSBTURCodec.encode(psbt)
            XCTAssertEqual(try PSBTURCodec.decode(encoded), psbt)
        }
    }

    func testMultipartRoundTripAcceptsReorderingAndDuplicates() throws {
        var psbt = Data([0x70, 0x73, 0x62, 0x74, 0xff])
        psbt.append(contentsOf: (0..<4_096).map { UInt8($0 % 251) })

        let encoder = try PSBTUREncoder(
            psbt: psbt,
            maximumFragmentLength: 80
        )
        XCTAssertFalse(encoder.isSinglePart)

        let frames = (0..<encoder.fragmentCount).map { _ in encoder.nextPart() }
        let decoder = PSBTURDecoder()
        var decoded: Data?
        for frame in ([frames.last!] + Array(frames.reversed()) + [frames.first!]) {
            let progress = try decoder.receive(frame)
            if progress.isComplete {
                decoded = progress.psbt
                break
            }
        }
        XCTAssertEqual(decoded, psbt)
    }

    func testFountainRedundancyRecoversDroppedOriginalFrames() throws {
        var psbt = Data([0x70, 0x73, 0x62, 0x74, 0xff])
        psbt.append(contentsOf: (0..<2_048).map { UInt8($0 % 239) })
        let encoder = try PSBTUREncoder(psbt: psbt, maximumFragmentLength: 80)
        let decoder = PSBTURDecoder()
        var decoded: Data?

        for index in 0..<(encoder.fragmentCount * 4) {
            let frame = encoder.nextPart()
            if index < encoder.fragmentCount, index.isMultiple(of: 4) {
                continue
            }
            let progress = try decoder.receive(frame)
            if progress.isComplete {
                decoded = progress.psbt
                break
            }
        }
        XCTAssertEqual(decoded, psbt)
    }

    func testRejectsWrongTypeNonCanonicalCBORAndBadMagic() throws {
        let wrongType = try UR(type: "bytes", cbor: CBOR.data(smallPSBT))
        XCTAssertThrowsError(try PSBTURCodec.decode(wrongType))

        let badMagic = try UR(type: "crypto-psbt", cbor: CBOR.data(Data([0x00])))
        XCTAssertThrowsError(try PSBTURCodec.decode(badMagic))

        var trailingCBOR = CBOR.data(smallPSBT).cborEncode
        trailingCBOR.append(0x00)
        let nonCanonical = try UR(type: "crypto-psbt", cbor: trailingCBOR)
        XCTAssertThrowsError(try PSBTURCodec.decode(nonCanonical))

        let nestedCBOR = try UR(type: "crypto-psbt", cbor: CBOR.array([.data(smallPSBT)]))
        XCTAssertThrowsError(try PSBTURCodec.decode(nestedCBOR))

        var nonMinimalLength = Data([0x58, UInt8(smallPSBT.count)])
        nonMinimalLength.append(smallPSBT)
        let nonCanonicalLength = try UR(type: "crypto-psbt", cbor: nonMinimalLength)
        XCTAssertThrowsError(try PSBTURCodec.decode(nonCanonicalLength))
    }

    func testRejectsPayloadAndFragmentFloodAboveLimits() throws {
        let tinyLimits = URTransportLimits(
            maximumPayloadBytes: 8,
            maximumFragments: 2,
            maximumFragmentCharacters: 512,
            maximumProcessedParts: 4
        )
        let oversized = Data([0x70, 0x73, 0x62, 0x74, 0xff, 1, 2, 3, 4])
        XCTAssertThrowsError(try PSBTURCodec.encode(oversized, limits: tinyLimits)) { error in
            XCTAssertEqual(error as? ColdSignerError, .payloadTooLarge)
        }

        XCTAssertThrowsError(
            try PSBTURDecoder(limits: tinyLimits).receive("ur:crypto-psbt/1-3/abcd")
        ) { error in
            XCTAssertEqual(error as? ColdSignerError, .payloadTooLarge)
        }
    }

    func testCancellationDropsPartialDecoderState() throws {
        var psbt = Data([0x70, 0x73, 0x62, 0x74, 0xff])
        psbt.append(Data(repeating: 0x42, count: 512))
        let encoder = try PSBTUREncoder(psbt: psbt, maximumFragmentLength: 40)
        let firstFrame = encoder.nextPart()
        let decoder = PSBTURDecoder()
        XCTAssertFalse(try decoder.receive(firstFrame).isComplete)

        decoder.cancel()
        let restarted = try decoder.receive(firstFrame)
        XCTAssertEqual(restarted.processedPartCount, 1)
        XCTAssertFalse(restarted.isComplete)
    }
}
