import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension View {
    /// Keine automatische Großschreibung, keine Korrektur (Slugs, Namen).
    @ViewBuilder
    public func plainTextInput() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.never).autocorrectionDisabled()
        #else
        self.autocorrectionDisabled()
        #endif
    }

    @ViewBuilder
    public func numberInput() -> some View {
        #if os(iOS)
        self.keyboardType(.numberPad)
        #else
        self
        #endif
    }

    @ViewBuilder
    public func inlineTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// Vollbild auf iOS, Sheet auf macOS.
    @ViewBuilder
    public func fullScreen<Item: Identifiable, Content: View>(item: Binding<Item?>, @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        #if os(iOS)
        self.fullScreenCover(item: item, content: content)
        #else
        self.sheet(item: item, content: content)
        #endif
    }
}

public enum Haptics {
    public static func tap() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    public static func success() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    public static func warning() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }
}

public enum IdleTimer {
    public static func setDisabled(_ disabled: Bool) {
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = disabled
        #endif
    }
}

extension Color {
    public init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    public static let ownTeam = Color(red: 0.12, green: 0.40, blue: 0.85)
    public static let opponent = Color(red: 0.85, green: 0.20, blue: 0.20)
    public static let pitchGreen = Color(red: 0.22, green: 0.52, blue: 0.28)
}

/// Große, kontrastreiche Taste für das Match Center.
public struct BigButtonStyle: ButtonStyle {
    var color: Color
    var minHeight: CGFloat
    var foreground: Color

    public init(color: Color, minHeight: CGFloat = 60, foreground: Color = .white) {
        self.color = color
        self.minHeight = minHeight
        self.foreground = foreground
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(configuration.isPressed ? 0.7 : 1)))
            .contentShape(Rectangle())
    }
}

public struct ErrorAlertModifier: ViewModifier {
    @Binding var message: String?

    public func body(content: Content) -> some View {
        content.alert("Fehler", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }
}

extension View {
    public func errorAlert(_ message: Binding<String?>) -> some View {
        modifier(ErrorAlertModifier(message: message))
    }
}
