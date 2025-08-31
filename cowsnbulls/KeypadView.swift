import SwiftUI

struct KeypadView: View {
    var keyTap: (String) -> Void

    var body: some View {
        VStack(spacing: 10) {
            let rows: [[String]] = [["1","2","3"],["4","5","6"],["7","8","9"],["⌫","0","⏎"]]
            ForEach(0..<rows.count, id: \.self) { r in
                HStack(spacing: 10) {
                    ForEach(rows[r], id: \.self) { label in
                        Button { keyTap(label) } label: {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.white.opacity(0.9))
                                .overlay(
                                    Text(label).font(.title3.weight(.semibold)).foregroundStyle(.black)
                                )
                                .frame(height: 54)
                                .shadow(radius: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.top, 6)
    }
}

