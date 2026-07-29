import ColdSignerPSBT
import Foundation

@_cdecl("LLVMFuzzerTestOneInput")
public func fuzzPSBT(
    _ bytes: UnsafePointer<UInt8>?,
    _ count: Int
) -> Int32 {
    guard let bytes,
          count >= 0,
          count <= TransactionPolicyLimits.v0_1.maximumPSBTBytes else {
        return 0
    }

    let input = Data(bytes: bytes, count: count)
    do {
        _ = try StrictPSBTStructureParser.parse(input)
    } catch is ColdSignerError {
        // Rejections are expected. The fuzz invariant is bounded completion
        // without a trap, memory violation, or foreign parser exception.
    } catch {
        preconditionFailure("strict parser leaked a foreign error: \(type(of: error))")
    }
    return 0
}
