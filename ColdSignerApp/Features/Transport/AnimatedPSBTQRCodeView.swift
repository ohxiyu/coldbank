import ColdSignerTransport
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import SwiftUI

struct AnimatedPSBTQRCodeView: View {
    let psbt: Data
    let format: PSBTOpticalFormat
    var framesPerSecond = 5.0
    var maximumFragmentLength = 250

    @State private var encoder: PSBTAnimatedEncoder?
    @State private var currentFrame: String?
    @State private var errorMessage: String?

    private let context = CIContext(options: [.useSoftwareRenderer: false])

    var body: some View {
        VStack(spacing: 12) {
            Group {
                if let currentFrame, let image = qrImage(for: currentFrame) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .accessibilityLabel("动画 PSBT 二维码")
                } else if let errorMessage {
                    ErrorCard(message: errorMessage)
                } else {
                    ProgressView("正在生成 \(format.displayName)…")
                }
            }
            .padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: 16))

            if let encoder {
                Text("\(format.displayName) · \(encoder.fragmentCount) 片 · \(Int(framesPerSecond)) fps")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear(perform: prepare)
        .onDisappear(perform: clear)
        .onReceive(
            Timer.publish(
                every: 1 / min(max(framesPerSecond, 1), 10),
                on: .main,
                in: .common
            ).autoconnect()
        ) { _ in
            advance()
        }
    }

    private func prepare() {
        do {
            let encoder: PSBTAnimatedEncoder
            switch format {
            case .bcUR:
                encoder = .bcUR(
                    try PSBTUREncoder(
                        psbt: psbt,
                        maximumFragmentLength: maximumFragmentLength
                    )
                )
            case .bbqr:
                encoder = .bbqr(
                    try PSBTBBQREncoder(
                        psbt: psbt,
                        encoding: .hex,
                        maximumFragmentLength: max(maximumFragmentLength, 600)
                    )
                )
            }
            self.encoder = encoder
            currentFrame = encoder.nextPart()
        } catch {
            errorMessage = "无法生成受限 \(format.displayName) 二维码。"
        }
    }

    private func advance() {
        guard let encoder else { return }
        currentFrame = encoder.nextPart()
    }

    private func clear() {
        encoder = nil
        currentFrame = nil
        errorMessage = nil
    }

    private func qrImage(for value: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        filter.correctionLevel = "L"
        guard let output = filter.outputImage else { return nil }

        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

private enum PSBTAnimatedEncoder {
    case bcUR(PSBTUREncoder)
    case bbqr(PSBTBBQREncoder)

    var fragmentCount: Int {
        switch self {
        case .bcUR(let encoder): encoder.fragmentCount
        case .bbqr(let encoder): encoder.fragmentCount
        }
    }

    func nextPart() -> String {
        switch self {
        case .bcUR(let encoder): encoder.nextPart()
        case .bbqr(let encoder): encoder.nextPart()
        }
    }
}
