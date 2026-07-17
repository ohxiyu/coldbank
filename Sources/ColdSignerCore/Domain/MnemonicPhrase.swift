import Foundation

public struct MnemonicPhrase: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    private let words: [String]

    public init(words: [String]) throws {
        guard words.count == 12 || words.count == 24 else {
            throw ColdSignerError.unsupportedWordCount(words.count)
        }
        self.words = words
    }

    public var wordCount: Int { words.count }
    public var description: String { "[REDACTED mnemonic: \(words.count) words]" }
    public var debugDescription: String { description }

    public func withUnsafeWords<Result>(_ body: ([String]) throws -> Result) rethrows -> Result {
        try body(words)
    }

    package var unsafeJoinedWords: String { words.joined(separator: " ") }
}
