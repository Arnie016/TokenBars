import SwiftUI

enum TokenBarTheme {
    static let canvas = Color(red: 0.075, green: 0.078, blue: 0.082)
    static let sidebar = Color(red: 0.055, green: 0.058, blue: 0.062)
    static let panel = Color(red: 0.105, green: 0.109, blue: 0.114)
    static let raised = Color(red: 0.132, green: 0.137, blue: 0.143)
    static let border = Color.white.opacity(0.105)
    static let text = Color(red: 0.93, green: 0.93, blue: 0.91)
    static let secondary = Color(red: 0.62, green: 0.63, blue: 0.62)
    static let green = Color(red: 0.43, green: 0.82, blue: 0.63)
    static let cyan = Color(red: 0.38, green: 0.72, blue: 0.80)
    static let amber = Color(red: 0.91, green: 0.66, blue: 0.35)
    static let coral = Color(red: 0.92, green: 0.47, blue: 0.42)

    static func accent(for seed: String) -> Color {
        let value = seed.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
        return [green, cyan, amber, coral][abs(value) % 4]
    }
}

struct TokenBarPanel<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(TokenBarTheme.panel)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(TokenBarTheme.border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct TokenBarPill: View {
    let label: String
    let value: String
    var tint: Color = TokenBarTheme.secondary

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(TokenBarTheme.secondary)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(TokenBarTheme.text)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(TokenBarTheme.raised)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(1.1)
            .foregroundStyle(TokenBarTheme.secondary)
    }
}
