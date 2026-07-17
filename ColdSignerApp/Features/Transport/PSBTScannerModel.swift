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

    private let profile: WalletProfile
    private let vault: any WalletVault
    private var decoder = PSBTURDecoder()
    private var seenFrameDigests = Set<Data>()
    private var unsignedPSBT: Data?
    private var sessionIdentifier: UUID?
    private var sessionTimeoutTask: Task<Void, Never>?

    init(profile: WalletProfile, vault: any WalletVault) {
        self.profile = profile
        self.vault = vault
    }

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
            clearDecoderState()
        } catch {
            errorMessage = ColdSignerError.invalidTransportPayload.errorDescription
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
        decoder.cancel()
        decoder = PSBTURDecoder()
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
