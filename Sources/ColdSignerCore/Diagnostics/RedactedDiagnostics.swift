import Foundation

public struct SensitiveValue: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public enum Kind: String, Sendable {
        case mnemonic
        case seed
        case privateKey
        case descriptor
        case psbt
        case address
    }

    public let kind: Kind

    public init(kind: Kind) {
        self.kind = kind
    }

    public var description: String { "[REDACTED \(kind.rawValue)]" }
    public var debugDescription: String { description }
}

public struct DiagnosticEvent: Codable, Equatable, Sendable {
    public let code: String
    public let integerMetadata: [String: Int]

    public init(code: String, integerMetadata: [String: Int] = [:]) {
        self.code = code
        self.integerMetadata = integerMetadata
    }
}
