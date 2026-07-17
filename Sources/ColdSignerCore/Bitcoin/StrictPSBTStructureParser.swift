import CryptoKit
import Foundation

public struct PSBTDerivationClaim: Equatable, Sendable {
    public let compressedPublicKey: Data
    public let fingerprint: String
    public let path: [UInt32]
}

public struct PSBTTransactionInputStructure: Equatable, Sendable {
    public let previousTransactionID: Data
    public let outputIndex: UInt32
    public let sequence: UInt32
}

public struct PSBTTransactionOutputStructure: Equatable, Sendable {
    public let valueSatoshis: UInt64
    public let scriptPubKey: Data
}

public struct PSBTInputMapStructure: Equatable, Sendable {
    public let hasNonWitnessUTXO: Bool
    public let nonWitnessUTXOCommitment: Data?
    public let witnessUTXO: PSBTTransactionOutputStructure?
    public let sighashType: UInt32?
    public let derivations: [PSBTDerivationClaim]
    public let partialSignatureCount: Int
}

public struct PSBTOutputMapStructure: Equatable, Sendable {
    public let derivations: [PSBTDerivationClaim]
}

public struct StrictPSBTStructure: Equatable, Sendable {
    public let psbtVersion: UInt32
    public let unsignedTransaction: Data
    public let transactionVersion: Int32
    public let lockTime: UInt32
    public let transactionInputs: [PSBTTransactionInputStructure]
    public let transactionOutputs: [PSBTTransactionOutputStructure]
    public let inputMaps: [PSBTInputMapStructure]
    public let outputMaps: [PSBTOutputMapStructure]
}

public enum StrictPSBTStructureParser {
    private static let magic = Data([0x70, 0x73, 0x62, 0x74, 0xff])
    private static let maximumMapEntries = 2_048
    private static let maximumMapKeyBytes = 1_024
    private static let maximumScriptBytes = 10_000
    private static let maximumBitcoinAmount = UInt64(21_000_000) * 100_000_000

    public static func parse(
        _ psbt: Data,
        limits: TransactionPolicyLimits = .v0_1
    ) throws -> StrictPSBTStructure {
        try parse(psbt, limits: limits, allowPartialSignatures: false)
    }

    static func parseSignedResult(
        _ psbt: Data,
        limits: TransactionPolicyLimits = .v0_1
    ) throws -> StrictPSBTStructure {
        try parse(psbt, limits: limits, allowPartialSignatures: true)
    }

    private static func parse(
        _ psbt: Data,
        limits: TransactionPolicyLimits,
        allowPartialSignatures: Bool
    ) throws -> StrictPSBTStructure {
        guard psbt.count <= limits.maximumPSBTBytes else {
            throw ColdSignerError.payloadTooLarge
        }
        guard psbt.starts(with: magic) else {
            throw ColdSignerError.invalidPSBT
        }

        var cursor = DataCursor(data: psbt, offset: magic.count)
        let globalMap = try readMap(from: &cursor)
        var unsignedTransaction: Data?
        var psbtVersion: UInt32 = 0

        for entry in globalMap {
            guard let type = entry.key.first else {
                throw ColdSignerError.invalidPSBT
            }
            switch type {
            case 0x00:
                guard entry.key.count == 1, unsignedTransaction == nil else {
                    throw ColdSignerError.invalidPSBT
                }
                unsignedTransaction = entry.value
            case 0x01:
                try validateGlobalXpub(entry, limits: limits)
            case 0xfb:
                guard entry.key.count == 1, entry.value.count == 4 else {
                    throw ColdSignerError.invalidPSBT
                }
                psbtVersion = decodeUInt32LE(entry.value)
            default:
                throw ColdSignerError.unsupportedPSBTField
            }
        }

        guard psbtVersion == 0 else {
            throw ColdSignerError.policyViolation(.unsupportedPSBTVersion)
        }
        guard let unsignedTransaction else {
            throw ColdSignerError.invalidPSBT
        }
        let transaction = try parseUnsignedTransaction(unsignedTransaction, limits: limits)

        var inputMaps: [PSBTInputMapStructure] = []
        inputMaps.reserveCapacity(transaction.inputs.count)
        for _ in transaction.inputs.indices {
            inputMaps.append(
                try parseInputMap(
                    readMap(from: &cursor),
                    limits: limits,
                    allowPartialSignatures: allowPartialSignatures
                )
            )
        }

        var outputMaps: [PSBTOutputMapStructure] = []
        outputMaps.reserveCapacity(transaction.outputs.count)
        for _ in transaction.outputs.indices {
            outputMaps.append(
                try parseOutputMap(readMap(from: &cursor), limits: limits)
            )
        }

        guard cursor.isAtEnd else {
            throw ColdSignerError.invalidPSBT
        }

        return StrictPSBTStructure(
            psbtVersion: psbtVersion,
            unsignedTransaction: unsignedTransaction,
            transactionVersion: transaction.version,
            lockTime: transaction.lockTime,
            transactionInputs: transaction.inputs,
            transactionOutputs: transaction.outputs,
            inputMaps: inputMaps,
            outputMaps: outputMaps
        )
    }

    private static func parseInputMap(
        _ entries: [MapEntry],
        limits: TransactionPolicyLimits,
        allowPartialSignatures: Bool
    ) throws -> PSBTInputMapStructure {
        var hasNonWitnessUTXO = false
        var nonWitnessUTXOCommitment: Data?
        var witnessUTXO: PSBTTransactionOutputStructure?
        var sighashType: UInt32?
        var derivations: [PSBTDerivationClaim] = []
        var partialSignatureCount = 0

        for entry in entries {
            guard let type = entry.key.first else {
                throw ColdSignerError.invalidPSBT
            }
            switch type {
            case 0x00:
                guard entry.key.count == 1, !entry.value.isEmpty else {
                    throw ColdSignerError.invalidPSBT
                }
                hasNonWitnessUTXO = true
                nonWitnessUTXOCommitment = Data(SHA256.hash(data: entry.value))
            case 0x01:
                guard entry.key.count == 1, witnessUTXO == nil else {
                    throw ColdSignerError.invalidPSBT
                }
                witnessUTXO = try parseTransactionOutput(entry.value)
            case 0x02:
                guard allowPartialSignatures else {
                    throw ColdSignerError.unsupportedPSBTField
                }
                try validatePartialSignature(entry)
                partialSignatureCount += 1
            case 0x03:
                guard entry.key.count == 1, entry.value.count == 4 else {
                    throw ColdSignerError.invalidPSBT
                }
                let value = decodeUInt32LE(entry.value)
                guard value == 1 else {
                    throw ColdSignerError.policyViolation(.unsupportedSighash)
                }
                sighashType = value
            case 0x06:
                derivations.append(try parseDerivation(entry, limits: limits))
            default:
                throw ColdSignerError.unsupportedPSBTField
            }
        }

        guard hasNonWitnessUTXO || witnessUTXO != nil else {
            throw ColdSignerError.policyViolation(.missingUTXO)
        }
        return PSBTInputMapStructure(
            hasNonWitnessUTXO: hasNonWitnessUTXO,
            nonWitnessUTXOCommitment: nonWitnessUTXOCommitment,
            witnessUTXO: witnessUTXO,
            sighashType: sighashType,
            derivations: derivations,
            partialSignatureCount: partialSignatureCount
        )
    }

    private static func validatePartialSignature(_ entry: MapEntry) throws {
        guard entry.key.count == 34,
              entry.key[entry.key.index(after: entry.key.startIndex)] == 0x02
                || entry.key[entry.key.index(after: entry.key.startIndex)] == 0x03,
              (9...74).contains(entry.value.count),
              entry.value.first == 0x30,
              entry.value.last == 0x01
        else {
            throw ColdSignerError.invalidSignedPSBT
        }
    }

    private static func parseOutputMap(
        _ entries: [MapEntry],
        limits: TransactionPolicyLimits
    ) throws -> PSBTOutputMapStructure {
        var derivations: [PSBTDerivationClaim] = []
        for entry in entries {
            guard entry.key.first == 0x02 else {
                throw ColdSignerError.unsupportedPSBTField
            }
            derivations.append(try parseDerivation(entry, limits: limits))
        }
        return PSBTOutputMapStructure(derivations: derivations)
    }

    private static func parseDerivation(
        _ entry: MapEntry,
        limits: TransactionPolicyLimits
    ) throws -> PSBTDerivationClaim {
        guard entry.key.count == 34,
              entry.key[entry.key.index(after: entry.key.startIndex)] == 0x02
                || entry.key[entry.key.index(after: entry.key.startIndex)] == 0x03,
              entry.value.count >= 4,
              (entry.value.count - 4).isMultiple(of: 4)
        else {
            throw ColdSignerError.invalidPSBT
        }

        let depth = (entry.value.count - 4) / 4
        guard depth <= limits.maximumDerivationDepth else {
            throw ColdSignerError.payloadTooLarge
        }

        let fingerprintBytes = entry.value.prefix(4)
        let fingerprint = fingerprintBytes
            .map { String(format: "%02X", $0) }
            .joined()
        var path: [UInt32] = []
        path.reserveCapacity(depth)
        for index in 0..<depth {
            let start = 4 + index * 4
            path.append(decodeUInt32LE(entry.value.subdata(in: start..<(start + 4))))
        }
        return PSBTDerivationClaim(
            compressedPublicKey: entry.key.dropFirst(),
            fingerprint: fingerprint,
            path: path
        )
    }

    private static func validateGlobalXpub(
        _ entry: MapEntry,
        limits: TransactionPolicyLimits
    ) throws {
        guard entry.key.count == 79,
              entry.value.count >= 4,
              (entry.value.count - 4).isMultiple(of: 4),
              (entry.value.count - 4) / 4 <= limits.maximumDerivationDepth
        else {
            throw ColdSignerError.invalidPSBT
        }
    }

    private static func parseUnsignedTransaction(
        _ transaction: Data,
        limits: TransactionPolicyLimits
    ) throws -> (
        version: Int32,
        lockTime: UInt32,
        inputs: [PSBTTransactionInputStructure],
        outputs: [PSBTTransactionOutputStructure]
    ) {
        var cursor = DataCursor(data: transaction)
        let version = Int32(bitPattern: try cursor.readUInt32LE())
        let inputCount = try cursor.readCompactSize()
        guard inputCount > 0 else { throw ColdSignerError.invalidPSBT }
        guard inputCount <= limits.maximumInputCount else {
            throw ColdSignerError.policyViolation(.tooManyInputs)
        }

        var inputs: [PSBTTransactionInputStructure] = []
        inputs.reserveCapacity(inputCount)
        for _ in 0..<inputCount {
            let transactionID = try cursor.readData(count: 32)
            let outputIndex = try cursor.readUInt32LE()
            let scriptLength = try cursor.readCompactSize()
            guard scriptLength == 0 else { throw ColdSignerError.invalidPSBT }
            let sequence = try cursor.readUInt32LE()
            inputs.append(
                PSBTTransactionInputStructure(
                    previousTransactionID: transactionID,
                    outputIndex: outputIndex,
                    sequence: sequence
                )
            )
        }

        let outputCount = try cursor.readCompactSize()
        guard outputCount > 0 else { throw ColdSignerError.invalidPSBT }
        guard outputCount <= limits.maximumOutputCount else {
            throw ColdSignerError.policyViolation(.tooManyOutputs)
        }

        var outputs: [PSBTTransactionOutputStructure] = []
        outputs.reserveCapacity(outputCount)
        var totalOutput: UInt64 = 0
        for _ in 0..<outputCount {
            let output = try parseTransactionOutput(from: &cursor)
            let (newTotal, overflow) = totalOutput.addingReportingOverflow(output.valueSatoshis)
            guard !overflow, newTotal <= maximumBitcoinAmount else {
                throw ColdSignerError.policyViolation(.amountOverflow)
            }
            totalOutput = newTotal
            outputs.append(output)
        }

        let lockTime = try cursor.readUInt32LE()
        guard cursor.isAtEnd else { throw ColdSignerError.invalidPSBT }
        return (version, lockTime, inputs, outputs)
    }

    private static func parseTransactionOutput(
        _ data: Data
    ) throws -> PSBTTransactionOutputStructure {
        var cursor = DataCursor(data: data)
        let output = try parseTransactionOutput(from: &cursor)
        guard cursor.isAtEnd else { throw ColdSignerError.invalidPSBT }
        return output
    }

    private static func parseTransactionOutput(
        from cursor: inout DataCursor
    ) throws -> PSBTTransactionOutputStructure {
        let value = try cursor.readUInt64LE()
        guard value <= maximumBitcoinAmount else {
            throw ColdSignerError.policyViolation(.amountOverflow)
        }
        let scriptLength = try cursor.readCompactSize()
        guard scriptLength <= maximumScriptBytes else {
            throw ColdSignerError.payloadTooLarge
        }
        let script = try cursor.readData(count: scriptLength)
        return PSBTTransactionOutputStructure(
            valueSatoshis: value,
            scriptPubKey: script
        )
    }

    private static func readMap(from cursor: inout DataCursor) throws -> [MapEntry] {
        var entries: [MapEntry] = []
        var keys = Set<Data>()
        while true {
            let keyLength = try cursor.readCompactSize()
            if keyLength == 0 { return entries }
            guard entries.count < maximumMapEntries,
                  keyLength <= maximumMapKeyBytes
            else {
                throw ColdSignerError.payloadTooLarge
            }
            let key = try cursor.readData(count: keyLength)
            guard keys.insert(key).inserted else {
                throw ColdSignerError.duplicatePSBTKey
            }
            let valueLength = try cursor.readCompactSize()
            let value = try cursor.readData(count: valueLength)
            entries.append(MapEntry(key: key, value: value))
        }
    }

    private static func decodeUInt32LE(_ data: Data) -> UInt32 {
        data.enumerated().reduce(0) { result, item in
            result | (UInt32(item.element) << UInt32(item.offset * 8))
        }
    }
}

private struct MapEntry {
    let key: Data
    let value: Data
}

private struct DataCursor {
    let data: Data
    private(set) var offset: Int

    init(data: Data, offset: Int = 0) {
        self.data = data
        self.offset = offset
    }

    var isAtEnd: Bool { offset == data.count }

    mutating func readData(count: Int) throws -> Data {
        guard count >= 0,
              offset <= data.count,
              count <= data.count - offset
        else {
            throw ColdSignerError.invalidPSBT
        }
        defer { offset += count }
        return data.subdata(in: offset..<(offset + count))
    }

    mutating func readByte() throws -> UInt8 {
        guard offset < data.count else { throw ColdSignerError.invalidPSBT }
        defer { offset += 1 }
        return data[data.index(data.startIndex, offsetBy: offset)]
    }

    mutating func readUInt32LE() throws -> UInt32 {
        let value = try readData(count: 4)
        return value.enumerated().reduce(0) { result, item in
            result | (UInt32(item.element) << UInt32(item.offset * 8))
        }
    }

    mutating func readUInt64LE() throws -> UInt64 {
        let value = try readData(count: 8)
        return value.enumerated().reduce(0) { result, item in
            result | (UInt64(item.element) << UInt64(item.offset * 8))
        }
    }

    mutating func readCompactSize() throws -> Int {
        let prefix = try readByte()
        let value: UInt64
        switch prefix {
        case 0x00...0xfc:
            value = UInt64(prefix)
        case 0xfd:
            let bytes = try readData(count: 2)
            value = bytes.enumerated().reduce(0) { result, item in
                result | (UInt64(item.element) << UInt64(item.offset * 8))
            }
            guard value >= 0xfd else { throw ColdSignerError.invalidPSBT }
        case 0xfe:
            value = UInt64(try readUInt32LE())
            guard value > UInt64(UInt16.max) else { throw ColdSignerError.invalidPSBT }
        case 0xff:
            value = try readUInt64LE()
            guard value > UInt64(UInt32.max) else { throw ColdSignerError.invalidPSBT }
        default:
            throw ColdSignerError.invalidPSBT
        }
        guard value <= UInt64(Int.max) else { throw ColdSignerError.payloadTooLarge }
        return Int(value)
    }
}
