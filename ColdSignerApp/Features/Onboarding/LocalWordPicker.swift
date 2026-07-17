import SwiftUI

struct LocalWordPicker: View {
    let prompt: String
    let onSelect: (String) -> Void
    @State private var prefix = ""

    private var candidates: [String] {
        guard !prefix.isEmpty else { return [] }
        return Array(BIP39WordList.english.lazy.filter { $0.hasPrefix(prefix) }.prefix(8))
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(prompt)
                .font(.headline)

            HStack {
                Text(prefix.isEmpty ? "输入单词前四个字母" : prefix)
                    .font(.title3.monospaced().weight(.semibold))
                    .foregroundStyle(prefix.isEmpty ? .secondary : .primary)
                Spacer()
                Button {
                    if !prefix.isEmpty { prefix.removeLast() }
                } label: {
                    Image(systemName: "delete.left")
                        .frame(width: 44, height: 44)
                }
                .disabled(prefix.isEmpty)
                .accessibilityLabel("删除一个字母")
            }
            .padding(.horizontal, 14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

            if !candidates.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                    ForEach(candidates, id: \.self) { word in
                        Button(word) {
                            onSelect(word)
                            prefix = ""
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                    }
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array("abcdefghijklmnopqrstuvwxyz"), id: \.self) { letter in
                    Button(String(letter)) {
                        guard prefix.count < 4 else { return }
                        prefix.append(letter)
                    }
                    .font(.body.monospaced().weight(.semibold))
                    .frame(minWidth: 38, minHeight: 42)
                    .background(Color.secondary.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
                    .disabled(prefix.count >= 4)
                }
            }

            Text("这是应用内置的离线 BIP39 单词键盘，不会调用系统键盘、粘贴板或自动纠错。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
