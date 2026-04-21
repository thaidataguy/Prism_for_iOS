import SwiftUI

enum PrismMotion {
    static let press = Animation.spring(response: 0.24, dampingFraction: 0.72)
    static let entrance = Animation.spring(response: 0.5, dampingFraction: 0.82)
    static let pulse = Animation.spring(response: 0.28, dampingFraction: 0.62)
    static let drift = Animation.easeInOut(duration: 9).repeatForever(autoreverses: true)
}

private struct PrismMotionEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var orbitMotionEnabled: Bool {
        get { self[PrismMotionEnabledKey.self] }
        set { self[PrismMotionEnabledKey.self] = newValue }
    }
}

struct PrismPressableButtonStyle: ButtonStyle {
    @Environment(\.orbitMotionEnabled) private var motionEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var allowsMotion: Bool {
        motionEnabled && !reduceMotion
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(allowsMotion && configuration.isPressed ? 0.975 : 1)
            .brightness(configuration.isPressed ? -0.01 : 0)
            .shadow(
                color: .black.opacity(configuration.isPressed ? 0.12 : 0.18),
                radius: configuration.isPressed ? 10 : 18,
                x: 0,
                y: configuration.isPressed ? 5 : 12
            )
            .animation(allowsMotion ? PrismMotion.press : nil, value: configuration.isPressed)
    }
}

struct PrismAmbientBackground: View {
    @Environment(\.orbitMotionEnabled) private var motionEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDrifting = false

    private var allowsMotion: Bool {
        motionEnabled && !reduceMotion
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.07, blue: 0.14),
                        Color(red: 0.07, green: 0.10, blue: 0.18),
                        Color(red: 0.09, green: 0.08, blue: 0.13)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                ambientOrb(
                    color: PrismColors.career.opacity(0.26),
                    size: proxy.size.width * 0.72,
                    x: isDrifting ? proxy.size.width * 0.36 : proxy.size.width * 0.22,
                    y: isDrifting ? proxy.size.height * 0.18 : proxy.size.height * 0.08
                )

                ambientOrb(
                    color: PrismColors.health.opacity(0.18),
                    size: proxy.size.width * 0.58,
                    x: isDrifting ? proxy.size.width * 0.78 : proxy.size.width * 0.62,
                    y: isDrifting ? proxy.size.height * 0.58 : proxy.size.height * 0.68
                )

                ambientOrb(
                    color: PrismColors.social.opacity(0.20),
                    size: proxy.size.width * 0.5,
                    x: isDrifting ? proxy.size.width * 0.18 : proxy.size.width * 0.1,
                    y: isDrifting ? proxy.size.height * 0.85 : proxy.size.height * 0.72
                )
            }
            .ignoresSafeArea()
            .drawingGroup()
        }
        .onAppear {
            guard allowsMotion else { return }
            isDrifting = true
        }
        .animation(allowsMotion ? PrismMotion.drift : nil, value: isDrifting)
    }

    private func ambientOrb(color: Color, size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: 80)
            .position(x: x, y: y)
    }
}

private struct PrismEntranceModifier: ViewModifier {
    let delay: Double

    @Environment(\.orbitMotionEnabled) private var motionEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    private var allowsMotion: Bool {
        motionEnabled && !reduceMotion
    }

    func body(content: Content) -> some View {
        content
            .opacity(allowsMotion ? (isVisible ? 1 : 0.001) : 1)
            .scaleEffect(allowsMotion ? (isVisible ? 1 : 0.97) : 1)
            .offset(y: allowsMotion ? (isVisible ? 0 : 18) : 0)
            .animation(allowsMotion ? PrismMotion.entrance.delay(delay) : nil, value: isVisible)
            .onAppear {
                guard !isVisible else { return }
                isVisible = true
            }
    }
}

private struct PrismValuePulseModifier<Value: Equatable>: ViewModifier {
    let value: Value
    let tint: Color

    @Environment(\.orbitMotionEnabled) private var motionEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    private var allowsMotion: Bool {
        motionEnabled && !reduceMotion
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(allowsMotion && isPulsing ? 1.05 : 1)
            .shadow(
                color: allowsMotion && isPulsing ? tint.opacity(0.24) : .clear,
                radius: allowsMotion && isPulsing ? 18 : 0,
                x: 0,
                y: 0
            )
            .animation(allowsMotion ? PrismMotion.pulse : nil, value: isPulsing)
            .onChange(of: value) { _ in
                guard allowsMotion else { return }
                pulse()
            }
    }

    private func pulse() {
        isPulsing = true

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            isPulsing = false
        }
    }
}

extension View {
    func orbitEntrance(delay: Double = 0) -> some View {
        modifier(PrismEntranceModifier(delay: delay))
    }

    func orbitValuePulse<Value: Equatable>(value: Value, tint: Color) -> some View {
        modifier(PrismValuePulseModifier(value: value, tint: tint))
    }
}
