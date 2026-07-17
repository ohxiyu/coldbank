import ColdSignerCore
import CZlib
import Foundation

public enum PSBTBBQREncoding: Character, Sendable {
    case hex = "H"
    case base32 = "2"
}

public struct PSBTBBQRDecodeProgress: Equatable, Sendable {
    public let processedPartCount: Int
    public let expectedPartCount: Int?
    public let estimatedPercentComplete: Double
    public let psbt: Data?

    public var isComplete: Bool { psbt != nil }
}

public final class PSBTBBQREncoder {
    public let fragmentCount: Int
    public let isSinglePart: Bool

    private let parts: [String]
    private var nextIndex = 0

    public init(
        psbt: Data,
        encoding: PSBTBBQREncoding = .hex,
        maximumFragmentLength: Int = 600,
        limits: URTransportLimits = .init()
    ) throws {
        try PSBTBBQR.validatePSBT(psbt, limits: limits)
        guard (32...4_296).contains(maximumFragmentLength) else {
            throw ColdSignerError.invalidTransportPayload
        }

        let encoded: String
        let quantum: Int
        switch encoding {
        case .hex:
            encoded = psbt.map { String(format: "%02X", $0) }.joined()
            quantum = 2
        case .base32:
            encoded = PSBTBBQR.encodeBase32(psbt)
            quantum = 8
        }

        let rawCapacity = maximumFragmentLength - PSBTBBQR.headerLength
        let bodyCapacity = rawCapacity - (rawCapacity % quantum)
        guard bodyCapacity >= quantum else {
            throw ColdSignerError.invalidTransportPayload
        }
        let count = max(1, (encoded.count + bodyCapacity - 1) / bodyCapacity)
        guard count <= min(limits.maximumFragments, PSBTBBQR.maximumPartCount) else {
            throw ColdSignerError.payloadTooLarge
        }

        var generated: [String] = []
        generated.reserveCapacity(count)
        var start = encoded.startIndex
        for index in 0..<count {
            let remaining = encoded.distance(from: start, to: encoded.endIndex)
            let length = min(bodyCapacity, remaining)
            let end = encoded.index(start, offsetBy: length)
            generated.append(
                "B$\(encoding.rawValue)P\(PSBTBBQR.base36(count))\(PSBTBBQR.base36(index))"
                    + encoded[start..<end]
            )
            start = end
        }
        parts = generated
        fragmentCount = count
        isSinglePart = count == 1
    }

    public func nextPart() -> String {
        defer { nextIndex = (nextIndex + 1) % parts.count }
        return parts[nextIndex]
    }
}

public final class PSBTBBQRDecoder {
    private let limits: URTransportLimits
    private var encoding: Character?
    private var expectedParts: Int?
    private var parts: [Int: String] = [:]
    private var processedParts = 0
    private var storedCharacterCount = 0

    public init(limits: URTransportLimits = .init()) {
        self.limits = limits
    }

    @discardableResult
    public func receive(_ part: String) throws -> PSBTBBQRDecodeProgress {
        do {
            let parsed = try PSBTBBQR.parseHeader(part, limits: limits)
            guard processedParts < limits.maximumProcessedParts else {
                throw ColdSignerError.payloadTooLarge
            }
            processedParts += 1

            if let encoding, encoding != parsed.encoding {
                throw ColdSignerError.invalidTransportPayload
            }
            if let expectedParts, expectedParts != parsed.total {
                throw ColdSignerError.invalidTransportPayload
            }
            encoding = parsed.encoding
            expectedParts = parsed.total

            if let existing = parts[parsed.index] {
                guard existing == parsed.body else {
                    throw ColdSignerError.invalidTransportPayload
                }
            } else {
                let maximumEncodedCharacters = PSBTBBQR.maximumEncodedCharacters(
                    for: parsed.encoding,
                    maximumPayloadBytes: limits.maximumPayloadBytes
                )
                guard parsed.body.count <= maximumEncodedCharacters,
                      storedCharacterCount <= maximumEncodedCharacters - parsed.body.count
                else {
                    throw ColdSignerError.payloadTooLarge
                }
                parts[parsed.index] = parsed.body
                storedCharacterCount += parsed.body.count
            }

            guard parts.count == parsed.total else {
                return PSBTBBQRDecodeProgress(
                    processedPartCount: processedParts,
                    expectedPartCount: parsed.total,
                    estimatedPercentComplete: Double(parts.count) / Double(parsed.total),
                    psbt: nil
                )
            }

            let psbt = try decodeCompletePayload()
            let result = PSBTBBQRDecodeProgress(
                processedPartCount: processedParts,
                expectedPartCount: parsed.total,
                estimatedPercentComplete: 1,
                psbt: psbt
            )
            reset()
            return result
        } catch let error as ColdSignerError {
            reset()
            throw error
        } catch {
            reset()
            throw ColdSignerError.invalidTransportPayload
        }
    }

    public func cancel() {
        reset()
    }

    private func decodeCompletePayload() throws -> Data {
        guard let encoding, let expectedParts else {
            throw ColdSignerError.invalidTransportPayload
        }
        let ordered = try (0..<expectedParts).map { index -> String in
            guard let part = parts[index] else {
                throw ColdSignerError.invalidTransportPayload
            }
            return part
        }
        if ordered.count > 1 {
            let regularLength = ordered[0].count
            guard ordered.dropLast().allSatisfy({ $0.count == regularLength }),
                  ordered.last!.count <= regularLength
            else {
                throw ColdSignerError.invalidTransportPayload
            }
        }

        let joined = ordered.joined()
        let decoded: Data
        switch encoding {
        case "H":
            decoded = try PSBTBBQR.decodeHex(joined)
        case "2":
            decoded = try PSBTBBQR.decodeBase32(joined)
        case "Z":
            let compressed = try PSBTBBQR.decodeBase32(joined)
            decoded = try PSBTBBQR.inflateRaw(
                compressed,
                maximumOutputBytes: limits.maximumPayloadBytes
            )
        default:
            throw ColdSignerError.invalidTransportPayload
        }
        try PSBTBBQR.validatePSBT(decoded, limits: limits)
        return decoded
    }

    private func reset() {
        encoding = nil
        expectedParts = nil
        parts.removeAll(keepingCapacity: false)
        processedParts = 0
        storedCharacterCount = 0
    }
}

private enum PSBTBBQR {
    static let headerLength = 8
    static let maximumPartCount = 1_295
    private static let psbtMagic = Data([0x70, 0x73, 0x62, 0x74, 0xff])
    private static let base32Alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".utf8)
    private static let base32Reverse = Dictionary(
        uniqueKeysWithValues: base32Alphabet.enumerated().map { ($0.element, $0.offset) }
    )

    static func validatePSBT(_ psbt: Data, limits: URTransportLimits) throws {
        guard psbt.count <= limits.maximumPayloadBytes else {
            throw ColdSignerError.payloadTooLarge
        }
        guard psbt.starts(with: psbtMagic) else {
            throw ColdSignerError.invalidTransportPayload
        }
    }

    static func maximumEncodedCharacters(
        for encoding: Character,
        maximumPayloadBytes: Int
    ) -> Int {
        switch encoding {
        case "H":
            return maximumPayloadBytes * 2
        case "2":
            return base32CharacterCount(forByteCount: maximumPayloadBytes)
        case "Z":
            // Raw DEFLATE can add a small overhead for incompressible input. Keep the
            // compressed staging buffer bounded while allowing any valid v0.1 PSBT.
            let maximumCompressedBytes = maximumPayloadBytes
                + maximumPayloadBytes / 16
                + 64
            return base32CharacterCount(forByteCount: maximumCompressedBytes)
        default:
            return 0
        }
    }

    static func parseHeader(
        _ part: String,
        limits: URTransportLimits
    ) throws -> (encoding: Character, total: Int, index: Int, body: String) {
        guard part.count > headerLength,
              part == part.uppercased(),
              part.unicodeScalars.allSatisfy({ $0.isASCII && !$0.properties.isWhitespace }),
              part.hasPrefix("B$")
        else {
            throw ColdSignerError.invalidTransportPayload
        }
        guard part.count <= min(limits.maximumFragmentCharacters, 4_296) else {
            throw ColdSignerError.payloadTooLarge
        }
        let characters = Array(part)
        let encoding = characters[2]
        guard encoding == "H" || encoding == "2" || encoding == "Z",
              characters[3] == "P",
              let total = decodeBase36(characters[4], characters[5]),
              let index = decodeBase36(characters[6], characters[7]),
              total > 0,
              index < total
        else {
            throw ColdSignerError.invalidTransportPayload
        }
        guard total <= min(limits.maximumFragments, maximumPartCount) else {
            throw ColdSignerError.payloadTooLarge
        }
        let body = String(characters.dropFirst(headerLength))
        guard !body.isEmpty else { throw ColdSignerError.invalidTransportPayload }
        switch encoding {
        case "H":
            guard body.count.isMultiple(of: 2),
                  body.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) })
            else {
                throw ColdSignerError.invalidTransportPayload
            }
        case "2", "Z":
            guard body.utf8.allSatisfy({ base32Reverse[$0] != nil }) else {
                throw ColdSignerError.invalidTransportPayload
            }
            if index < total - 1, !body.count.isMultiple(of: 8) {
                throw ColdSignerError.invalidTransportPayload
            }
        default:
            throw ColdSignerError.invalidTransportPayload
        }
        return (encoding, total, index, body)
    }

    static func base36(_ value: Int) -> String {
        let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        return String([alphabet[(value / 36) % 36], alphabet[value % 36]])
    }

    static func decodeHex(_ value: String) throws -> Data {
        let bytes = Array(value.utf8)
        guard bytes.count.isMultiple(of: 2) else {
            throw ColdSignerError.invalidTransportPayload
        }
        var result = Data(capacity: bytes.count / 2)
        for index in stride(from: 0, to: bytes.count, by: 2) {
            guard let high = hexNibble(bytes[index]),
                  let low = hexNibble(bytes[index + 1])
            else {
                throw ColdSignerError.invalidTransportPayload
            }
            result.append((high << 4) | low)
        }
        return result
    }

    static func encodeBase32(_ data: Data) -> String {
        var output: [UInt8] = []
        output.reserveCapacity((data.count * 8 + 4) / 5)
        var buffer: UInt32 = 0
        var bitCount = 0
        for byte in data {
            buffer = (buffer << 8) | UInt32(byte)
            bitCount += 8
            while bitCount >= 5 {
                bitCount -= 5
                output.append(base32Alphabet[Int((buffer >> UInt32(bitCount)) & 0x1f)])
            }
            if bitCount > 0 {
                buffer &= (1 << UInt32(bitCount)) - 1
            } else {
                buffer = 0
            }
        }
        if bitCount > 0 {
            output.append(base32Alphabet[Int((buffer << UInt32(5 - bitCount)) & 0x1f)])
        }
        return String(decoding: output, as: UTF8.self)
    }

    private static func base32CharacterCount(forByteCount count: Int) -> Int {
        (count * 8 + 4) / 5
    }

    static func decodeBase32(_ value: String) throws -> Data {
        var result = Data()
        result.reserveCapacity(value.count * 5 / 8)
        var buffer: UInt32 = 0
        var bitCount = 0
        for character in value.utf8 {
            guard let digit = base32Reverse[character] else {
                throw ColdSignerError.invalidTransportPayload
            }
            buffer = (buffer << 5) | UInt32(digit)
            bitCount += 5
            while bitCount >= 8 {
                bitCount -= 8
                result.append(UInt8((buffer >> UInt32(bitCount)) & 0xff))
            }
            if bitCount > 0 {
                buffer &= (1 << UInt32(bitCount)) - 1
            } else {
                buffer = 0
            }
        }
        guard bitCount < 5, buffer == 0 else {
            throw ColdSignerError.invalidTransportPayload
        }
        return result
    }

    static func inflateRaw(
        _ compressed: Data,
        maximumOutputBytes: Int
    ) throws -> Data {
        guard !compressed.isEmpty else {
            throw ColdSignerError.invalidTransportPayload
        }
        var stream = z_stream()
        guard inflateInit2_(&stream, -10, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            throw ColdSignerError.invalidTransportPayload
        }
        defer { inflateEnd(&stream) }

        var output = Data()
        var input = [UInt8](compressed)
        var exceededOutputLimit = false
        let status: Int32 = input.withUnsafeMutableBytes { inputBuffer in
            stream.next_in = inputBuffer.bindMemory(to: Bytef.self).baseAddress
            stream.avail_in = uInt(inputBuffer.count)
            var finalStatus = Int32(Z_OK)
            var chunk = [UInt8](repeating: 0, count: 16_384)

            repeat {
                let produced: Int = chunk.withUnsafeMutableBytes { outputBuffer in
                    stream.next_out = outputBuffer.bindMemory(to: Bytef.self).baseAddress
                    stream.avail_out = uInt(outputBuffer.count)
                    finalStatus = inflate(&stream, Z_NO_FLUSH)
                    return outputBuffer.count - Int(stream.avail_out)
                }
                if produced > 0 {
                    guard produced <= maximumOutputBytes,
                          output.count <= maximumOutputBytes - produced
                    else {
                        exceededOutputLimit = true
                        finalStatus = Int32(Z_MEM_ERROR)
                        break
                    }
                    output.append(contentsOf: chunk.prefix(produced))
                }
                if finalStatus == Z_OK, produced == 0, stream.avail_in == 0 {
                    finalStatus = Int32(Z_DATA_ERROR)
                }
            } while finalStatus == Z_OK
            return finalStatus
        }
        if exceededOutputLimit {
            throw ColdSignerError.payloadTooLarge
        }
        guard status == Z_STREAM_END, stream.avail_in == 0 else {
            if output.count >= maximumOutputBytes {
                throw ColdSignerError.payloadTooLarge
            }
            throw ColdSignerError.invalidTransportPayload
        }
        return output
    }

    private static func decodeBase36(_ first: Character, _ second: Character) -> Int? {
        guard let high = base36Digit(first), let low = base36Digit(second) else { return nil }
        return high * 36 + low
    }

    private static func base36Digit(_ value: Character) -> Int? {
        guard let byte = value.asciiValue else { return nil }
        switch byte {
        case 48...57: return Int(byte - 48)
        case 65...90: return Int(byte - 65) + 10
        default: return nil
        }
    }

    private static func hexNibble(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 48...57: byte - 48
        case 65...70: byte - 65 + 10
        default: nil
        }
    }
}
