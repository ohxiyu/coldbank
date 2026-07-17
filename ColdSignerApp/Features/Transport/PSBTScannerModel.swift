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
    @Published private(set) var review: PSBTReview?
    @Published private(set) var signedPSBT: Data?
    @Published private(set) var signedInputCount: Int?
    @Published private(set) var isSigning = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var transportFormat: PSBTOpticalFormat?

    private let profile: WalletProfile
    private let vault: any WalletVault
    private var urDecoder = PSBTURDecoder()
    private var bbqrDecoder = PSBTBBQRDecoder()
    private var seenFrameDigests = Set<Data>()
    private var unsignedPSBT: Data?
    private var sessionIdentifier: UUID?
    private var sessionTimeoutTask: Task<Void, Never>?
    private var requiresExplicitRestart = false

    init(profile: WalletProfile, vault: any WalletVault) {
        self.profile = profile
        self.vault = vault
    }

    func receive(_ value: String) {
        guard completedPSBTByteCount == nil,
              !requiresExplicitRestart,
              value.count <= URTransportLimits().maximumFragmentCharacters,
              let incomingFormat = PSBTOpticalFormat.detect(value)
        else {
            return
        }

        if let transportFormat, transportFormat != incomingFormat {
            errorMessage = "输入格式在扫描过程中从 \(transportFormat.displayName) 切换为 \(incomingFormat.displayName)。为避免混淆，已清空本次扫描，请重新开始。"
            requiresExplicitRestart = true
            self.transportFormat = nil
            clearDecoderState()
            return
        }
        transportFormat = incomingFormat

        let frameDigest = Data(SHA256.hash(data: Data(value.utf8)))
        guard seenFrameDigests.insert(frameDigest).inserted else { return }

        do {
            let progress: (processed: Int, expected: Int?, percent: Double, psbt: Data?)
            switch incomingFormat {
            case .bcUR:
                let decoded = try urDecoder.receive(value)
                progress = (
                    decoded.processedPartCount,
                    decoded.expectedPartCount,
                    decoded.estimatedPercentComplete,
                    decoded.psbt
                )
            case .bbqr:
                let decoded = try bbqrDecoder.receive(value)
                progress = (
                    decoded.processedPartCount,
                    decoded.expectedPartCount,
                    decoded.estimatedPercentComplete,
                    decoded.psbt
                )
            }
            processedPartCount = progress.processed
            expectedPartCount = progress.expected
            percentComplete = progress.percent
            errorMessage = nil

            if let psbt = progress.psbt {
                clearDecoderState()
                let review = try PSBTPolicyEngine().review(
                    psbt: psbt,
                    profile: profile
                )
                completedPSBTByteCount = psbt.count
                completedPSBTDigest = review.commitment.displayValue
                unsignedPSBT = psbt
                self.review = review
                let identifier = UUID()
                sessionIdentifier = identifier
                scheduleSessionTimeout(for: identifier)
            }
        } catch let error as ColdSignerError {
            errorMessage = error.errorDescription ?? error.userMessage
            transportFormat = nil
            clearDecoderState()
        } catch {
            errorMessage = ColdSignerError.invalidTransportPayload.errorDescription
            transportFormat = nil
            clearDecoderState()
        }
    }

    func restart() {
        sessionTimeoutTask?.cancel()
        sessionTimeoutTask = nil
        sessionIdentifier = nil
        unsignedPSBT = nil
        review = nil
        signedPSBT = nil
        signedInputCount = nil
        isSigning = false
        completedPSBTByteCount = nil
        completedPSBTDigest = nil
        errorMessage = nil
        processedPartCount = 0
        expectedPartCount = nil
        percentComplete = 0
        transportFormat = nil
        requiresExplicitRestart = false
        clearDecoderState()
    }

    func cancel() {
        restart()
    }

    func sign() async {
        guard !isSigning,
              signedPSBT == nil,
              let unsignedPSBT,
              let review,
              let sessionIdentifier
        else {
            return
        }

        isSigning = true
        errorMessage = nil
        do {
            let setup = try await vault.unlock(
                localizedReason: "确认签署已复核的 Bitcoin PSBT"
            )
            guard self.sessionIdentifier == sessionIdentifier else { return }
            guard setup.profile == profile else {
                throw ColdSignerError.policyViolation(.ownershipNotProven)
            }
            let result = try await Task.detached(priority: .userInitiated) {
                try PSBTSigner().sign(
                    psbt: unsignedPSBT,
                    reviewedAs: review,
                    using: setup
                )
            }.value
            guard self.sessionIdentifier == sessionIdentifier else { return }
            guard result.commitment == review.commitment else {
                throw ColdSignerError.invalidSignedPSBT
            }

            self.unsignedPSBT = nil
            signedPSBT = result.signedPSBT
            signedInputCount = result.signedInputCount
            scheduleSessionTimeout(for: sessionIdentifier)
        } catch let error as ColdSignerError where error == .operationCancelled {
            guard self.sessionIdentifier == sessionIdentifier else { return }
            errorMessage = nil
        } catch let error as ColdSignerError {
            guard self.sessionIdentifier == sessionIdentifier else { return }
            errorMessage = error.errorDescription ?? error.userMessage
        } catch {
            guard self.sessionIdentifier == sessionIdentifier else { return }
            errorMessage = ColdSignerError.signingFailed.errorDescription
        }
        guard self.sessionIdentifier == sessionIdentifier else { return }
        isSigning = false
    }

    private func clearDecoderState() {
        urDecoder.cancel()
        bbqrDecoder.cancel()
        urDecoder = PSBTURDecoder()
        bbqrDecoder = PSBTBBQRDecoder()
        seenFrameDigests.removeAll(keepingCapacity: false)
    }

    private func scheduleSessionTimeout(for identifier: UUID) {
        sessionTimeoutTask?.cancel()
        sessionTimeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.expireSession(identifier: identifier)
        }
    }

    private func expireSession(identifier: UUID) {
        guard sessionIdentifier == identifier else { return }
        restart()
        errorMessage = "\(ColdSignerError.sessionExpired.code): 签名会话已超时，PSBT 已从内存清除。请重新扫描。"
    }
}
