import ColdSignerCore
import LocalAuthentication

struct DeviceOwnerAuthenticator {
    func requireAvailability() throws {
        let context = LAContext()
        var evaluationError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &evaluationError) else {
            throw ColdSignerError.ownerAuthenticationUnavailable
        }
    }

    func authenticate(localizedReason: String) async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var evaluationError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &evaluationError) else {
            throw ColdSignerError.ownerAuthenticationUnavailable
        }

        do {
            guard try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: localizedReason
            ) else {
                throw ColdSignerError.ownerAuthenticationFailed
            }
        } catch let error as LAError where error.code == .userCancel || error.code == .systemCancel || error.code == .appCancel {
            throw ColdSignerError.operationCancelled
        } catch {
            throw ColdSignerError.ownerAuthenticationFailed
        }
    }
}
