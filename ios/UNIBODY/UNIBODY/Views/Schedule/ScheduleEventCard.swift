import SwiftUI

public struct ScheduleEventCard: View {
    public let event: ScheduleEvent
    public var onToggle: () -> Void = {}
    public var onDelete: () -> Void = {}
    
    private var isEnrolled: Bool {
        event.type == "enrolled_exercise"
    }
    
    private var isLecture: Bool {
        event.type == "lecture"
    }
    
    private var cardGradient: LinearGradient {
        if isEnrolled {
            return LinearGradient(
                colors: [Color(red: 0.05, green: 0.7, blue: 0.45).opacity(0.35), Color(red: 0.0, green: 0.5, blue: 0.35).opacity(0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isLecture {
            return LinearGradient(
                colors: [Color(red: 0.0, green: 0.55, blue: 0.95).opacity(0.25), Color(red: 0.0, green: 0.35, blue: 0.8).opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color(red: 0.85, green: 0.5, blue: 0.05).opacity(0.25), Color(red: 0.7, green: 0.35, blue: 0.0).opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        if isEnrolled {
                            AeroBadge("Eingeschrieben", icon: "checkmark.seal.fill", color: AeroTheme.emerald)
                        } else if isLecture {
                            AeroBadge("Vorlesung", icon: "book.fill", color: AeroTheme.skyBlue)
                        } else {
                            AeroBadge("Übung", icon: "person.2.fill", color: AeroTheme.solarOrange)
                        }
                        
                        if event.weekType == "A" {
                            AeroBadge("Woche A", color: Color.purple)
                        } else if event.weekType == "B" {
                            AeroBadge("Woche B", color: Color.indigo)
                        }
                    }
                    
                    Text(event.title)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundColor(event.enabled ? .primary : .secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
                
                Spacer()
                
                Button(action: onToggle) {
                    Image(systemName: event.enabled ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(event.enabled ? (isEnrolled ? AeroTheme.emerald : AeroTheme.skyBlue) : .secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("\(event.startTime) – \(event.endTime)")
                        .font(.caption.weight(.medium))
                }
                
                if !event.room.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.caption2)
                        Text(event.room)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                    }
                }
            }
            .foregroundColor(.secondary)
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(cardGradient)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.4), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .opacity(event.enabled ? 1.0 : 0.6)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Aus Plan entfernen", systemImage: "trash")
            }
        }
    }
}
