import ColdSignerPSBT
import Foundation

private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var value = state
        value = (value ^ (value >> 30)) &* 0xbf58476d1ce4e5b9
        value = (value ^ (value >> 27)) &* 0x94d049bb133111eb
        return value ^ (value >> 31)
    }
}

@main
private enum ColdSignerPSBTSanitizerRunner {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            fputs("usage: ColdSignerPSBTSanitizerRunner <unsigned-psbt-base64>\n", stderr)
            exit(64)
        }

        let fixtureURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let fixtureText = try String(contentsOf: fixtureURL, encoding: .utf8)
        guard let fixture = Data(
            base64Encoded: fixtureText,
            options: .ignoreUnknownCharacters
        ) else {
            throw ColdSignerError.invalidPSBT
        }

        _ = try StrictPSBTStructureParser.parse(fixture)
        var executions = 1

        for length in 0...fixture.count {
            exercise(fixture.prefix(length))
            executions += 1
        }

        for index in fixture.indices {
            for mask: UInt8 in [0x01, 0x80, 0xff] {
                var candidate = fixture
                candidate[index] ^= mask
                exercise(candidate)
                executions += 1
            }
        }

        var generator = SplitMix64(seed: 0x434f4c445349474e)
        for _ in 0..<4_096 {
            let length = Int(generator.next() % 2_049)
            var candidate = Data(count: length)
            candidate.withUnsafeMutableBytes { buffer in
                for index in buffer.indices {
                    buffer[index] = UInt8(truncatingIfNeeded: generator.next())
                }
            }
            exercise(candidate)
            executions += 1
        }

        exercise(Data(repeating: 0, count: TransactionPolicyLimits.v0_1.maximumPSBTBytes))
        exercise(Data(repeating: 0, count: TransactionPolicyLimits.v0_1.maximumPSBTBytes + 1))
        executions += 2

        print("PSBT sanitizer corpus passed \(executions) bounded parser executions.")
    }

    private static func exercise<D: DataProtocol>(_ bytes: D) {
        do {
            _ = try StrictPSBTStructureParser.parse(Data(bytes))
        } catch is ColdSignerError {
            // Policy and structural rejection is expected for hostile inputs.
        } catch {
            preconditionFailure("strict parser leaked a foreign error: \(type(of: error))")
        }
    }
}
