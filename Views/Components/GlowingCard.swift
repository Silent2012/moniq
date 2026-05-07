import SwiftUI

// MARK: - GlowingCard

struct GlowingCard<Content: View>: View {
    let content: Content
    var accentColor: Color
    var padding: CGFloat

    @State private var isHovered = false
    @State private var isPressed = false

    init(
        accentColor: Color = DS.Colors.primaryAccent,
        padding: CGFloat = DS.Layout.cardPadding,
        @ViewBuilder content: () -> Content
    ) {
        self.accentColor = accentColor
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(cardBackground)
            .overlay(cardBorder)
            .shadow(
                color: accentColor.opacity(isHovered ? 0.25 : 0.12),
                radius: isHovered ? 30 : 20,
                x: 0, y: isHovered ? 12 : 8
            )
            .scaleEffect(isPressed ? 0.98 : (isHovered ? 1.005 : 1.0))
            .animation(DS.Animations.spring, value: isHovered)
            .animation(DS.Animations.spring, value: isPressed)
            .onHover { hovering in
                isHovered = hovering
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) { isPressed = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isPressed = false }
                }
            }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: DS.Layout.cardCornerRadius)
            .fill(isHovered ? DS.Colors.tertiaryBackground : DS.Colors.secondaryBackground)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: DS.Layout.cardCornerRadius)
            .strokeBorder(
                isHovered ? accentColor.opacity(0.4) : DS.Colors.cardBorder,
                lineWidth: 1
            )
    }
}

// MARK: - GlowingCard with tap action

struct TappableGlowingCard<Content: View>: View {
    let content: Content
    var accentColor: Color
    var padding: CGFloat
    var action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    init(
        accentColor: Color = DS.Colors.primaryAccent,
        padding: CGFloat = DS.Layout.cardPadding,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.accentColor = accentColor
        self.padding = padding
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isPressed = false }
                action()
            }
        }) {
            content
                .padding(padding)
                .background(cardBackground)
                .overlay(cardBorder)
        }
        .buttonStyle(.plain)
        .shadow(
            color: accentColor.opacity(isHovered ? 0.25 : 0.12),
            radius: isHovered ? 30 : 20,
            x: 0, y: isHovered ? 12 : 8
        )
        .scaleEffect(isPressed ? 0.98 : (isHovered ? 1.005 : 1.0))
        .animation(DS.Animations.spring, value: isHovered)
        .animation(DS.Animations.spring, value: isPressed)
        .onHover { hovering in isHovered = hovering }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: DS.Layout.cardCornerRadius)
            .fill(isHovered ? DS.Colors.tertiaryBackground : DS.Colors.secondaryBackground)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: DS.Layout.cardCornerRadius)
            .strokeBorder(
                isHovered ? accentColor.opacity(0.4) : DS.Colors.cardBorder,
                lineWidth: 1
            )
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 16) {
        GlowingCard(accentColor: DS.Colors.secondaryAccent) {
            VStack(alignment: .leading, spacing: 8) {
                Text("CPU Usage").font(DS.Fonts.cardTitle()).foregroundColor(DS.Colors.primaryText)
                Text("47%").font(DS.Fonts.heroNumber()).foregroundColor(DS.Colors.secondaryAccent)
            }
        }
        .frame(width: 200, height: 120)

        GlowingCard(accentColor: DS.Colors.pinkAccent) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Memory").font(DS.Fonts.cardTitle()).foregroundColor(DS.Colors.primaryText)
                Text("8.2 GB").font(DS.Fonts.heroNumber()).foregroundColor(DS.Colors.pinkAccent)
            }
        }
        .frame(width: 200, height: 120)
    }
    .padding()
    .background(DS.Colors.primaryBackground)
}
