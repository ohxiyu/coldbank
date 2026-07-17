import ColdSignerCore
import XCTest

final class CoreDomainTests: XCTestCase {
    func testOfficialBIP84Vector() throws {
        let words = Array(repeating: "abandon", count: 11) + ["about"]
        let setup = try BDKWalletDeriver().restore(words: words, network: .bitcoin)

        XCTAssertEqual(setup.profile.fingerprint, "73C5DA0A")
        XCTAssertEqual(setup.profile.firstReceiveAddress, "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu")
        XCTAssertTrue(setup.profile.receiveDescriptor.hasSuffix("/0/*)#wc3n3van"))
    }

    func testEncryptedSeedRejectsWrongKey() throws {
        let words = Array(repeating: "abandon", count: 11) + ["about"]
        let setup = try BDKWalletDeriver().restore(words: words, network: .bitcoin)
        let cipher = AESGCMSeedCipher()
        let key = Data(repeating: 0x42, count: AESGCMSeedCipher.keyByteCount)
        let envelope = try cipher.seal(mnemonic: setup.mnemonic, profile: setup.profile, keyData: key)

        XCTAssertThrowsError(
            try cipher.open(
                envelope: envelope,
                profile: setup.profile,
                keyData: Data(repeating: 0x24, count: AESGCMSeedCipher.keyByteCount)
            )
        )
    }

    func testBIP39ResourceIsCompleteAndSorted() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "bip39-english", withExtension: "txt"))
        let content = try String(contentsOf: url, encoding: .utf8)
        let words = content.split(whereSeparator: \.isWhitespace).map(String.init)

        XCTAssertEqual(words.count, 2_048)
        XCTAssertEqual(words.first, "abandon")
        XCTAssertEqual(words.last, "zoo")
        XCTAssertEqual(words, words.sorted())
    }
}
