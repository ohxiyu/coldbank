import ColdSignerCore
import ColdSignerTransport
import CryptoKit
import Foundation

@MainActor
final class PSBTScannerModel: ObservableObject {
    @Published private(set) var processedPartCount = 0
    @Published private(set) var expectedPartCount: Int?
    @Published private(set) var percentComplete = 0.0
    @Published private(set) var completedPSBTByteCount: Int?
    @Published private(set) var completedPSBTDigest: String?
    @Published private(set) var errorMessage: String?

    private var decoder = PSBTURDecoder()
    private var seenFrameDigests = Set<Data>()

    func receive(_ value: String) {
        guard completedPSBTByteCount == nil,
              value.count <= URTransportLimits().maximumFragmentCharacters,
              value.lowercased().hasPrefix("ur:")
        else {
            return
        }

        let frameDigest = Data(SHA256.hash(data: Data(value.utf8)))
        guard seenFrameDigests.insert(frameDigest).inserted else { return }

        do {
            let progress = try decoder.receive(value)
            processedPartCount = progress.processedPartCount
            expectedPartCount = progress.expectedPartCount
            percentComplete = progress.estimatedPercentComplete
            errorMessage = nil

            if let psbt = progress.psbt {
                completedPSBTByteCount = psbt.count
                completedPSBTDigest = Data(SHA256.hash(data: psbt))
                    .prefix(6)
                    .map { String(format: "%02x", $0) }
                    .joined()
                // Only byte count and a short digest survive in UI state. M3 will own parsed PSBT state.
                clearDecoderState()
            }
        } catch let error as ColdSignerError {
            errorMessage = error.errorDescription ?? error.userMessage
            clearDecoderState()
        } catch {
            errorMessage = ColdSignerError.invalidTransportPayload.errorDescription
            clearDecoderState()
        }
    }

    func restart() {
        completedPSBTByteCount = nil
        completedPSBTDigest = nil
        errorMessage = nil
        processedPartCount = 0
        expectedPartCount = nil
        percentComplete = 0
        clearDecoderState()
    }

    func cancel() {
        restart()
    }

    private func clearDecoderState() {
        decoder.cancel()
        decoder = PSBTURDecoder()
        seenFrameDigests.removeAll(keepingCapacity: false)
    }
}
