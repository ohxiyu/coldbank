import ColdSignerCore
import Foundation
import URKit

public struct PSBTURDecodeProgress: Equatable, Sendable {
    public let processedPartCount: Int
    public let expectedPartCount: Int?
    public let estimatedPercentComplete: Double
    public let psbt: Data?

    public var isComplete: Bool { psbt != nil }
}

public final class PSBTURDecoder {
    private let limits: URTransportLimits
    private var decoder = URDecoder()

    public init(limits: URTransportLimits = .init()) {
        self.limits = limits
    }

    @discardableResult
    public func receive(_ part: String) throws -> PSBTURDecodeProgress {
        do {
            let preflight = try Self.preflight(part, limits: limits)
            guard PSBTURType(rawValue: preflight.type) != nil else {
                throw ColdSignerError.invalidTransportPayload
            }
            if let expectedPartCount = preflight.expectedPartCount,
               expectedPartCount > limits.maximumFragments {
                throw ColdSignerError.payloadTooLarge
            }
            guard decoder.processedPartsCount < limits.maximumProcessedParts else {
                throw ColdSignerError.payloadTooLarge
            }
            guard decoder.receivePart(part) else {
                throw ColdSignerError.invalidTransportPayload
            }

            if let expectedPartCount = decoder.expectedPartCount,
               expectedPartCount > limits.maximumFragments {
                throw ColdSignerError.payloadTooLarge
            }

            if let result = decoder.result {
                switch result {
                case .success(let ur):
                    let psbt = try PSBTURCodec.decode(ur, limits: limits)
                    let progress = PSBTURDecodeProgress(
                        processedPartCount: decoder.processedPartsCount,
                        expectedPartCount: decoder.expectedPartCount,
                        estimatedPercentComplete: 1,
                        psbt: psbt
                    )
                    reset()
                    return progress
                case .failure:
                    throw ColdSignerError.invalidTransportPayload
                }
            }

            return PSBTURDecodeProgress(
                processedPartCount: decoder.processedPartsCount,
                expectedPartCount: decoder.expectedPartCount,
                estimatedPercentComplete: decoder.estimatedPercentComplete,
                psbt: nil
            )
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

    private func reset() {
        decoder = URDecoder()
    }

    private static func preflight(
        _ part: String,
        limits: URTransportLimits
    ) throws -> (type: String, expectedPartCount: Int?) {
        guard !part.isEmpty,
              part.count <= limits.maximumFragmentCharacters,
              part.unicodeScalars.allSatisfy({ $0.isASCII && !$0.properties.isWhitespace })
        else {
            throw ColdSignerError.invalidTransportPayload
        }

        let lowered = part.lowercased()
        guard lowered.hasPrefix("ur:") else {
            throw ColdSignerError.invalidTransportPayload
        }
        let components = lowered.dropFirst(3).split(
            separator: "/",
            omittingEmptySubsequences: false
        )
        guard components.count == 2 || components.count == 3,
              !components.contains(where: { $0.isEmpty })
        else {
            throw ColdSignerError.invalidTransportPayload
        }

        let type = String(components[0])
        guard components.count == 3 else {
            return (type, nil)
        }

        let sequence = components[1].split(
            separator: "-",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        guard sequence.count == 2,
              let sequenceNumber = UInt64(sequence[0]),
              let sequenceLength = Int(sequence[1]),
              sequenceNumber > 0,
              sequenceNumber <= UInt64(UInt32.max),
              sequenceLength > 0
        else {
            throw ColdSignerError.invalidTransportPayload
        }
        return (type, sequenceLength)
    }
}
