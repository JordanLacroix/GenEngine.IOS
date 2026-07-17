import SwiftUI

enum GenEngineTheme {
    static let ink = Color(red: 0.025, green: 0.035, blue: 0.055)
    static let midnight = Color(red: 0.055, green: 0.075, blue: 0.11)
    static let ivory = Color(red: 0.96, green: 0.92, blue: 0.82)
    static let ember = Color(red: 0.94, green: 0.42, blue: 0.18)
    static let amber = Color(red: 0.96, green: 0.68, blue: 0.28)
    static let verdigris = Color(red: 0.25, green: 0.67, blue: 0.61)
    static let violet = Color(red: 0.53, green: 0.43, blue: 0.77)
    static let secondaryText = ivory.opacity(0.66)

    static func accent(_ accent: StoryAccent) -> Color {
        switch accent {
        case .ember: ember
        case .verdigris: verdigris
        case .violet: violet
        }
    }
}

struct StoryCanvas: View {
    var accent: Color = GenEngineTheme.ember

    var body: some View {
        ZStack {
            LinearGradient(colors: [GenEngineTheme.midnight, GenEngineTheme.ink], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(accent.opacity(0.18)).frame(width: 460).blur(radius: 110).offset(x: 180, y: -260)
            Circle().fill(GenEngineTheme.verdigris.opacity(0.09)).frame(width: 360).blur(radius: 100).offset(x: -190, y: 320)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct EyebrowText: View {
    let text: String
    var color = GenEngineTheme.amber

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(1.6)
            .foregroundStyle(color)
    }
}

struct PrimaryActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(GenEngineTheme.ink)
            .padding(.horizontal, 22)
            .frame(minHeight: 52)
            .background(LinearGradient(colors: [GenEngineTheme.amber, GenEngineTheme.ember], startPoint: .leading, endPoint: .trailing), in: Capsule())
            .shadow(color: GenEngineTheme.ember.opacity(configuration.isPressed ? 0.15 : 0.32), radius: configuration.isPressed ? 8 : 18, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.snappy(duration: 0.22), value: configuration.isPressed)
    }
}

struct GlassPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 28))
        } else {
            content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
    }
}

extension View {
    func glassPanel() -> some View { modifier(GlassPanelModifier()) }
}
