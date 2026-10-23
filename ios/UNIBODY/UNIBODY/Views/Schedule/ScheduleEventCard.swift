import SwiftUI

public struct ScheduleEventCard: View {
    @EnvironmentObject var appState: AppState
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
                    let resolvedRooms = CampusLocationEngine.resolveAll(room: event.room).filter { !$0.isOnline }
                    if resolvedRooms.count > 1 {
                        Menu {
                            ForEach(resolvedRooms) { res in
                                Button {
                                    CampusLocationEngine.openInAppleMaps(forResolved: res)
                                } label: {
                                    Label("\(res.displayTitle) in Apple Maps", systemImage: "map")
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.caption2)
                                Text(event.room)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            CampusLocationEngine.openInAppleMaps(for: event.room)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.caption2)
                                Text(event.room)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
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
            // 1. Status umschalten
            Button(action: onToggle) {
                if event.enabled {
                    Label("Aus Wochenplan ausblenden", systemImage: "eye.slash")
                } else {
                    Label("Im Wochenplan einblenden", systemImage: "eye")
                }
            }
            
            Divider()
            
            // 2. Raum kopieren & Campus Navigation
            if !event.room.isEmpty {
                Button {
                    UIPasteboard.general.string = event.room
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                } label: {
                    Label("Raum kopieren (\(event.room))", systemImage: "doc.on.doc")
                }
                
                if !event.room.lowercased().contains("online") {
                    let resolvedRooms = CampusLocationEngine.resolveAll(room: event.room).filter { !$0.isOnline }
                    ForEach(resolvedRooms) { res in
                        Button {
                            CampusLocationEngine.openInAppleMaps(forResolved: res)
                        } label: {
                            Label("\(res.displayTitle) in Apple Maps zeigen", systemImage: "map.fill")
                        }
                    }
                }
            }
            
            // 3. Titel kopieren
            Button {
                UIPasteboard.general.string = event.title
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
            } label: {
                Label("Titel kopieren", systemImage: "text.quote")
            }
            
            // 4. Termin teilen
            Button {
                let shareText = "\(event.title)\nTag: \(event.dayName), \(event.startTime) – \(event.endTime)\(event.room.isEmpty ? "" : "\nOrt: " + event.room)"
                let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    rootVC.present(activityVC, animated: true)
                }
            } label: {
                Label("Termin teilen...", systemImage: "square.and.arrow.up")
            }
            
            Divider()
            
            // 5. Löschen / Austragen
            if isEnrolled {
                Button(role: .destructive) {
                    if let cid = event.courseId {
                        appState.clearEnrollment(courseId: cid)
                    } else {
                        onDelete()
                    }
                } label: {
                    Label("Aus Übung austragen", systemImage: "xmark.seal.fill")
                }
            } else {
                Button(role: .destructive, action: onDelete) {
                    Label("Aus Plan entfernen", systemImage: "trash")
                }
            }
        } preview: {
            EventPreviewCard(event: event)
        }
    }
}

// MARK: - Rich Haptic Touch Preview Card
private struct EventPreviewCard: View {
    let event: ScheduleEvent
    
    private var isEnrolled: Bool { event.type == "enrolled_exercise" }
    private var isLecture: Bool { event.type == "lecture" }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
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
                
                Spacer()
                
                Text(event.dayName)
                    .font(.caption.weight(.bold))
                    .foregroundColor(AeroTheme.skyBlue)
            }
            
            Text(event.title)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            HStack(spacing: 16) {
                Label("\(event.startTime) – \(event.endTime)", systemImage: "clock.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white.opacity(0.9))
                
                if !event.room.isEmpty {
                    Label(event.room, systemImage: "mappin.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AeroTheme.solarOrange)
                        .lineLimit(1)
                }
            }
            
            HStack(spacing: 6) {
                Circle()
                    .fill(event.enabled ? AeroTheme.emerald : Color.secondary)
                    .frame(width: 8, height: 8)
                Text(event.enabled ? "Im Wochenplan aktiv" : "Aktuell ausgeblendet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(18)
        .frame(width: 310)
        .background(
            ZStack {
                Color(red: 0.02, green: 0.07, blue: 0.15)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), AeroTheme.skyBlue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
    }
}
