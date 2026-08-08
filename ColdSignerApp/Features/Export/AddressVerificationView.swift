import ColdSignerCore
import SwiftUI

struct AddressVerificationView: View {
    let profile: WalletProfile
    @State private var branch: WalletAddressBranch = .receive
    @State private var indexText = "0"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FlowHeader(
                    title: "验证收款地址",
                    subtitle: "地址由本机公开 descriptor 离线派生。协调器展示的地址必须与这里逐字符一致。"
                )

                Picker("分支", selection: $branch) {
                    Text("收款 (0/*)").tag(WalletAddressBranch.receive)
                    Text("找零 (1/*)").tag(WalletAddressBranch.change)
                }
                .pickerStyle(.segmented)

                HStack(spacing: 12) {
                    Text("地址序号")
                        .font(.body.weight(.semibold))
                    TextField("0", text: $indexText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 120)
                    Stepper("", value: boundIndex, in: 0...Int(WalletAddressDeriver.maximumVerificationIndex))
                        .labelsHidden()
                }

                switch derived {
                case .success(let address):
                    StaticQRCodeView(value: address)
                        .frame(maxWidth: 300)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(profile.accountPath)/\(branch == .receive ? 0 : 1)/\(boundIndex.wrappedValue)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        Text(address)
                            .font(.body.monospaced().weight(.semibold))
                            .textSelection(.disabled)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                case .failure:
                    ErrorCard(message: "序号无效。请输入 0 到 \(WalletAddressDeriver.maximumVerificationIndex) 之间的整数。")
                }

                NoticeCard(
                    title: "为什么要在这台设备上核对",
                    message: "联网协调器可能被攻破并展示攻击者地址。只有离线签名器派生的地址才可信。",
                    systemImage: "checkmark.shield"
                )
            }
            .padding(24)
        }
        .navigationTitle("地址验证")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var boundIndex: Binding<Int> {
        Binding(
            get: { Int(indexText) ?? 0 },
            set: { indexText = String($0) }
        )
    }

    private var derived: Result<String, Error> {
        guard let index = UInt32(indexText.trimmingCharacters(in: .whitespaces)),
              index <= WalletAddressDeriver.maximumVerificationIndex
        else {
            return .failure(ColdSignerError.invalidWalletDescriptor)
        }
        return Result {
            try WalletAddressDeriver.address(profile: profile, branch: branch, index: index)
        }
    }
}
