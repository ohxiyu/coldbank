import Foundation

enum BIP39WordList {
    static let english: [String] = {
        guard
            let url = Bundle.main.url(forResource: "bip39-english", withExtension: "txt"),
            let content = try? String(contentsOf: url, encoding: .utf8)
        else {
            return []
        }
        let words = content.split(whereSeparator: \.isWhitespace).map(String.init)
        guard
            words.count == 2_048,
            words.first == "abandon",
            words.last == "zoo",
            words == words.sorted()
        else {
            return []
        }
        return words
    }()
}
