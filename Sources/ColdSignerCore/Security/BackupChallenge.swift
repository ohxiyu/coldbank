import Foundation
import ColdSignerPSBT

public struct BackupChallenge: Equatable, Sendable {
    public let positions: [Int]

    public init(wordCount: Int, challengeCount: Int = 3) throws {
        guard wordCount == 12 || wordCount == 24 else {
            throw ColdSignerError.unsupportedWordCount(wordCount)
        }
        guard challengeCount > 0, challengeCount <= wordCount else {
            throw ColdSignerError.secureStorageFailure
        }
        positions = Array(0..<wordCount).shuffled().prefix(challengeCount).sorted()
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
