import Foundation

public enum PSBTOpticalFormat: String, CaseIterable, Equatable, Sendable {
    case bcUR
    case bbqr

    public var displayName: String {
        switch self {
        case .bcUR: "BC-UR"
        case .bbqr: "BBQr"
        }
    }

    public var hasExactProgress: Bool {
        self == .bbqr
    }

    public static func detect(_ frame: String) -> Self? {
        if frame.lowercased().hasPrefix("ur:") {
            return .bcUR
        }
        if frame.hasPrefix("B$") {
            return .bbqr
        }
        return nil
    }
}
