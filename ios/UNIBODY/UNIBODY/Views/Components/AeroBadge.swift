import SwiftUI

public struct AeroBadge: View {
    public let text: String
    public var icon: String? = nil
    public var color: Color = AeroTheme.skyBlue
    
    public init(_ text: String, icon: String? = nil, color: Color = AeroTheme.skyBlue) {
        self.text = text
        self.icon = icon
        self.color = color
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
            }
            Text(text)
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(color)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
        .overlay(
            Capsule()
                .strokeBorder(color.opacity(0.35), lineWidth: 0.8)
        )
    }
}

// MARK: - Easter Egg: Für Claire Modal View (Aesthetic Pastel Rose Glass)
public struct ClaireEasterEggModalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var heartScale: CGFloat = 1.0
    @State private var haloScale: CGFloat = 0.95
    @State private var haloOpacity: Double = 0.4
    @State private var floatingParticles: [ParticleItem] = []
    
    struct ParticleItem: Identifiable {
        let id = UUID()
        let symbol: String
        let xOffset: CGFloat
        var yOffset: CGFloat
        var opacity: Double
    }
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Soft Pearlescent Frosted Glass Backdrop
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color(red: 0.15, green: 0.06, blue: 0.12),
                        Color(red: 0.10, green: 0.03, blue: 0.08),
                        Color(red: 0.06, green: 0.01, blue: 0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.99, green: 0.97, blue: 0.98),
                        Color(red: 0.98, green: 0.93, blue: 0.95),
                        Color(red: 0.96, green: 0.89, blue: 0.93)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            
            // Ambient Floating Sparkles
            ForEach(floatingParticles) { p in
                Text(p.symbol)
                    .font(.system(size: 22))
                    .position(x: p.xOffset, y: p.yOffset)
                    .opacity(p.opacity)
            }
            
            // Specular Frosted Glass Curved Reflection
            VStack {
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.25 : 0.85),
                        Color.white.opacity(0.04)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 140)
                .cornerRadius(32)
                .padding(.horizontal, 10)
                .padding(.top, 4)
                Spacer()
            }
            .allowsHitTesting(false)
            
            // Main Content
            VStack(spacing: 16) {
                // Top Close Button
                HStack {
                    Spacer()
                    Button {
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.7) : Color(red: 0.65, green: 0.25, blue: 0.38))
                    }
                    .padding(.top, 16)
                    .padding(.trailing, 20)
                }
                
                Spacer()
                
                // Pulsing Center Heart with Gentle Rose Halo
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.96, green: 0.50, blue: 0.68).opacity(haloOpacity),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 85
                            )
                        )
                        .frame(width: 170, height: 170)
                        .scaleEffect(haloScale)
                    
                    Text("💖")
                        .font(.system(size: 76))
                        .scaleEffect(heartScale)
                        .shadow(color: Color(red: 0.94, green: 0.40, blue: 0.60).opacity(0.40), radius: 18, y: 6)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
                        heartScale = 1.14
                    }
                    withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                        haloScale = 1.28
                        haloOpacity = 0.70
                    }
                    startParticles()
                }
                
                // Title: Für Claire
                Text("Für Claire")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color(red: 1.0, green: 0.6, blue: 0.78), Color(red: 0.95, green: 0.4, blue: 0.65)]
                                : [Color(red: 0.62, green: 0.10, blue: 0.30), Color(red: 0.82, green: 0.20, blue: 0.45)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.pink.opacity(colorScheme == .dark ? 0.4 : 0.15), radius: 6, y: 2)
                
                // Subtitle Tag
                HStack(spacing: 6) {
                    Text("💕 Von Herzen gemacht ✨")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundColor(colorScheme == .dark ? Color(red: 1.0, green: 0.7, blue: 0.85) : Color(red: 0.60, green: 0.15, blue: 0.32))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.92))
                        .overlay(
                            Capsule()
                                .stroke(Color(red: 0.95, green: 0.50, blue: 0.70).opacity(0.45), lineWidth: 1)
                        )
                        .shadow(color: Color.pink.opacity(0.12), radius: 6, y: 2)
                )
                
                // Warm Romantic Message
                Text("Du bringst Licht in jeden Tag – ganz egal ob im Daylight- oder im Dark-Mode. 🌸")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.9) : Color(red: 0.32, green: 0.12, blue: 0.22))
                    .padding(.horizontal, 32)
                    .lineSpacing(4)
                
                // Floral Decoration Row
                HStack(spacing: 16) {
                    Text("🌸").font(.title3)
                    Text("✨").font(.title3)
                    Text("💖").font(.title3)
                    Text("✨").font(.title3)
                    Text("🌷").font(.title3)
                }
                .padding(.top, 4)
                
                Spacer()
                
                // Dismiss Action Button
                Button {
                    #if canImport(UIKit)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    #endif
                    dismiss()
                } label: {
                    Text("Hab dich lieb! 💖")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.96, green: 0.45, blue: 0.65),
                                    Color(red: 0.90, green: 0.25, blue: 0.50),
                                    Color(red: 0.80, green: 0.12, blue: 0.38)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
                        )
                        .shadow(color: Color(red: 0.85, green: 0.20, blue: 0.45).opacity(0.35), radius: 12, y: 6)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
    }
    
    private func startParticles() {
        let symbols = ["💖", "💕", "🌸", "✨", "💗", "🌷", "🤍"]
        for _ in 0..<12 {
            let p = ParticleItem(
                symbol: symbols.randomElement() ?? "💖",
                xOffset: CGFloat.random(in: 40...340),
                yOffset: CGFloat.random(in: 200...650),
                opacity: Double.random(in: 0.35...0.75)
            )
            floatingParticles.append(p)
        }
    }
}
