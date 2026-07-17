import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

struct StaticQRCodeView: View {
    let value: String

    var body: some View {
        Group {
            if let image = makeImage() {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel("公开钱包二维码")
            } else {
                ErrorCard(message: "此公开数据无法编码为静态二维码。")
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
    }

    private func makeImage() -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }

        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
