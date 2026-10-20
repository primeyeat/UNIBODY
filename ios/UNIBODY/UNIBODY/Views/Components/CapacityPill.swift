import SwiftUI

public struct CapacityPill: View {
    public let spotsFree: Int
    public let spotsTotal: Int
    
    public init(free: Int, total: Int) {
        self.spotsFree = free
        self.spotsTotal = total
    }
    
    private var isFull: Bool {
        spotsFree <= 0
    }
    
    private var color: Color {
        if isFull {
            return AeroTheme.rubyRed
        } else if spotsFree <= 5 {
            return AeroTheme.solarOrange
        } else {
            return AeroTheme.emerald
        }
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            
            if isFull {
                Text("Ausgebucht")
                    .font(.caption2.weight(.bold))
            } else {
                Text("\(spotsFree)/\(spotsTotal) frei")
                    .font(.caption2.weight(.semibold))
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .foregroundColor(color)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
        .overlay(
            Capsule()
                .strokeBorder(color.opacity(0.3), lineWidth: 0.8)
        )
    }
}
