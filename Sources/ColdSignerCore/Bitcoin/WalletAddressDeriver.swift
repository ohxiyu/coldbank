import BitcoinDevKit
import Foundation

public enum WalletAddressBranch: String, CaseIterable, Sendable {
    case receive
    case change
}

/// Derives addresses from the stored public descriptors so the signer can
/// display any coordinator-claimed address for offline verification. This
/// never touches the seed.
public enum WalletAddressDeriver {
    public static let maximumVerificationIndex: UInt32 = 9_999

    public static func address(
        profile: WalletProfile,
        branch: WalletAddressBranch,
        index: UInt32
    ) throws -> String {
        guard index <= maximumVerificationIndex else {
            throw ColdSignerError.invalidWalletDescriptor
        }
        do {
            let descriptor = try Descriptor(
                descriptor: branch == .receive
                    ? profile.receiveDescriptor
                    : profile.changeDescriptor,
                networkKind: profile.network.bdkNetworkKind
            )
            return try descriptor.deriveAddress(
                index: index,
                network: profile.network.bdkNetwork
            ).description
        } catch let error as ColdSignerError {
            throw error
        } catch {
            throw ColdSignerError.invalidWalletDescriptor
        }
    }
}
