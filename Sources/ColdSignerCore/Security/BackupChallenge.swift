import Foundation

public struct BackupChallenge: Equatable, Sendable {
    public let positions: [Int]

    /// Longer phrases get more probe positions because a 24-word backup has
    /// twice as many transcription opportunities to go wrong.
    public static func defaultChallengeCount(wordCount: Int) -> Int {
        wordCount == 24 ? 5 : 3
    }

    public init(wordCount: Int, challengeCount: Int? = nil) throws {
        guard wordCount == 12 || wordCount == 24 else {
            throw ColdSignerError.unsupportedWordCount(wordCount)
        }
        let resolvedCount = challengeCount ?? Self.defaultChallengeCount(wordCount: wordCount)
        guard resolvedCount > 0, resolvedCount <= wordCount else {
            throw ColdSignerError.secureStorageFailure
        }
        positions = Array(0..<wordCount).shuffled().prefix(resolvedCount).sorted()
    }

    public init(positions: [Int], wordCount: Int) throws {
        guard
            !positions.isEmpty,
            Set(positions).count == positions.count,
            positions.allSatisfy({ 0..<(wordCount) ~= $0 })
        else {
            throw ColdSignerError.secureStorageFailure
        }
        self.positions = positions.sorted()
    }

    public func verifies(_ answers: [Int: String], mnemonic: MnemonicPhrase) -> Bool {
        mnemonic.withUnsafeWords { words in
            positions.allSatisfy { position in
                guard let answer = answers[position] else { return false }
                return answer == words[position]
            }
        }
    }
}
