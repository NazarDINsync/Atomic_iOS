import SwiftUI

struct AmbientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.14), Color(.systemBackground)],
            startPoint: .top,
            endPoint: .center
        )
        .background(Color(.systemBackground))
        .ignoresSafeArea()
    }
}

// MARK: - Glass surfaces

extension View {
    /// Wraps the view in a Liquid Glass surface with a layered shadow for depth.
    func glassCard<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        let glass: Glass = tint.map { Glass.regular.tint($0) } ?? Glass.regular
        return self
            .glassEffect(glass.interactive(interactive), in: shape)
            .shadow(color: .black.opacity(0.12), radius: 20, y: 12)
            .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
    }

    /// A rounded-rectangle glass surface.
    func glassCard(cornerRadius: CGFloat = 24, tint: Color? = nil, interactive: Bool = false) -> some View {
        glassCard(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), tint: tint, interactive: interactive)
    }
}

/// A titled glass card that holds a group of related rows.
struct GlassSection<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
            }
            VStack(alignment: .leading, spacing: 0) { content }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
        }
    }
}

/// A hairline between rows inside a glass card.
struct GlassDivider: View {
    var body: some View {
        Divider().opacity(0.6).padding(.vertical, 10)
    }
}
