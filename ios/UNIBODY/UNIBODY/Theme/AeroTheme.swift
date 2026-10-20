import SwiftUI

public enum AeroTheme {
    // Primary Frutiger Aero palette
    public static let skyBlue = Color(red: 0.0, green: 0.635, blue: 1.0)
    public static let deepOcean = Color(red: 0.012, green: 0.078, blue: 0.141)
    public static let auroraGreen = Color(red: 0.063, green: 0.725, blue: 0.506)
    public static let emerald = Color(red: 0.133, green: 0.773, blue: 0.369)
    public static let solarOrange = Color(red: 1.0, green: 0.55, blue: 0.0)
    public static let rubyRed = Color(red: 0.94, green: 0.27, blue: 0.27)
    public static let vaporWhite = Color.white.opacity(0.92)
    
    // Adaptive Dynamic Text Colors
    public static func primaryTextColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : Color(red: 0.05, green: 0.16, blue: 0.28)
    }
    
    public static func secondaryTextColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.7) : Color(red: 0.28, green: 0.40, blue: 0.52)
    }
    
    // Gradients
    public static let oceanGradient = LinearGradient(
        colors: [Color(red: 0.0, green: 0.55, blue: 0.95), Color(red: 0.0, green: 0.3, blue: 0.75)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let auroraGradient = LinearGradient(
        colors: [Color(red: 0.05, green: 0.75, blue: 0.55), Color(red: 0.0, green: 0.55, blue: 0.95)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let darkSpaceGradient = LinearGradient(
        colors: [Color(red: 0.02, green: 0.08, blue: 0.16), Color(red: 0.01, green: 0.04, blue: 0.10)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    public static let lightSkyGradient = LinearGradient(
        colors: [Color(red: 0.94, green: 0.97, blue: 1.0), Color(red: 0.88, green: 0.93, blue: 0.98)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    public static func backgroundGradient(for colorScheme: ColorScheme) -> LinearGradient {
        colorScheme == .dark ? darkSpaceGradient : lightSkyGradient
    }
}

// MARK: - Reusable Adaptive Ambient Frutiger Aero Background
public struct AeroBackgroundView: View {
    @Environment(\.colorScheme) var colorScheme
    
    public init() {}
    
    public var body: some View {
        ZStack {
            AeroTheme.backgroundGradient(for: colorScheme)
            
            if colorScheme == .dark {
                Circle()
                    .fill(AeroTheme.skyBlue.opacity(0.18))
                    .frame(width: 320, height: 320)
                    .blur(radius: 80)
                    .offset(x: -120, y: -200)
                
                Circle()
                    .fill(AeroTheme.auroraGreen.opacity(0.15))
                    .frame(width: 280, height: 280)
                    .blur(radius: 70)
                    .offset(x: 140, y: 150)
            } else {
                Circle()
                    .fill(AeroTheme.skyBlue.opacity(0.18))
                    .frame(width: 340, height: 340)
                    .blur(radius: 85)
                    .offset(x: -100, y: -190)
                
                Circle()
                    .fill(Color(red: 0.35, green: 0.85, blue: 0.65).opacity(0.14))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(x: 130, y: 140)
            }
        }
        .drawingGroup()
        .ignoresSafeArea()
    }
}

// MARK: - Translucent Frutiger Aero Glass Modifier (Adaptive Dark/Light Mode)
public struct FrutigerGlassModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var cornerRadius: CGFloat = 16
    var isInteractive: Bool = false
    
    public func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.72))
                    
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    // Specular gloss reflection across the top
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.32 : 0.65),
                                    Color.white.opacity(colorScheme == .dark ? 0.06 : 0.15),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                    
                    // Luminous glass border
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.55 : 0.95),
                                    Color.white.opacity(colorScheme == .dark ? 0.15 : 0.35),
                                    AeroTheme.skyBlue.opacity(0.25)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(
                color: colorScheme == .dark ? Color.black.opacity(0.25) : Color(red: 0.05, green: 0.20, blue: 0.35).opacity(0.08),
                radius: 12, x: 0, y: 6
            )
    }
}

public struct GlossyButtonModifier: ViewModifier {
    var gradient: LinearGradient = AeroTheme.oceanGradient
    var cornerRadius: CGFloat = 14
    
    public func body(content: Content) -> some View {
        content
            .font(.system(.body, design: .rounded).weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(gradient)
                    
                    // Gel bubble top specular highlight
                    VStack {
                        RoundedRectangle(cornerRadius: cornerRadius - 2, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.55), Color.white.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 18)
                            .padding(.horizontal, 2)
                            .padding(.top, 2)
                        Spacer()
                    }
                    
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                }
            )
            .shadow(color: AeroTheme.skyBlue.opacity(0.35), radius: 8, x: 0, y: 4)
    }
}

public extension View {
    func frutigerGlass(cornerRadius: CGFloat = 16) -> some View {
        modifier(FrutigerGlassModifier(cornerRadius: cornerRadius))
    }
    
    func glossyButton(gradient: LinearGradient = AeroTheme.oceanGradient, cornerRadius: CGFloat = 14) -> some View {
        modifier(GlossyButtonModifier(gradient: gradient, cornerRadius: cornerRadius))
    }
}
