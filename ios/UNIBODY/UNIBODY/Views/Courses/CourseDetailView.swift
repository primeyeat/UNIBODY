import SwiftUI

public struct CourseDetailView: View {
    @EnvironmentObject var appState: AppState
    public let course: Course
    
    @State private var showSniperSheet = false
    
    private var enrolledGroupId: String? {
        appState.enrolledGroups[course.courseId]
    }
    
    public var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.08, blue: 0.16),
                    Color(red: 0.01, green: 0.04, blue: 0.1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            AeroBadge(course.platformHost, icon: course.platformId == "openolat" ? "building.columns.fill" : "bolt.fill")
                            AeroBadge(course.enrollmentMode == "sniper" ? "Sniper FCFS" : "Prioritäten", color: AeroTheme.solarOrange)
                        }
                        
                        Text(course.title)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundColor(.white)
                        
                        if !course.lecturer.isEmpty {
                            Text("Dozent: \(course.lecturer)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Image(systemName: "timer")
                                .font(.caption2)
                            Text("Anmeldebeginn: \(course.enrollmentOpensAt.replacingOccurrences(of: "T", with: " um ")) Uhr")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundColor(AeroTheme.skyBlue)
                        .padding(.top, 4)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frutigerGlass(cornerRadius: 18)
                    
                    // Sniper Shortcut
                    Button {
                        showSniperSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "cross.circle.fill")
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sniper / Prioritäten scharfstellen")
                                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                                Text("Automatische Anmeldung sekundengenau bei Freischaltung")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title3)
                        }
                        .padding(14)
                        .glossyButton(gradient: AeroTheme.auroraGradient, cornerRadius: 16)
                    }
                    .buttonStyle(.plain)
                    
                    // Group List Header
                    Text("Verfügbare Übungsgruppen (\(course.groups.count))")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.top, 6)
                    
                    // Active Enrolled Group Banner with Unenroll Option
                    if let gid = enrolledGroupId, let grp = course.groups.first(where: { $0.groupId == gid }) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(AeroTheme.emerald)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Aktuell belegte Gruppe")
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(AeroTheme.emerald)
                                    Text(grp.name)
                                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    appState.clearEnrollment(courseId: course.courseId)
                                } label: {
                                    Label("Austragen", systemImage: "xmark.circle.fill")
                                        .font(.caption.weight(.bold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(Color.red.opacity(0.85)))
                                        .foregroundColor(.white)
                                }
                            }
                            
                            HStack(spacing: 12) {
                                Label("\(grp.dayName) \(grp.startTime)–\(grp.endTime)", systemImage: "clock")
                                if !grp.room.isEmpty {
                                    Label(grp.room, systemImage: "mappin.and.ellipse")
                                }
                            }
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AeroTheme.emerald.opacity(0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(AeroTheme.emerald.opacity(0.4), lineWidth: 1)
                                )
                        )
                    }
                    
                    // Groups
                    LazyVStack(spacing: 12) {
                        ForEach(course.groups) { grp in
                            GroupDetailCard(
                                group: grp,
                                courseId: course.courseId,
                                isEnrolled: enrolledGroupId == grp.groupId,
                                onEnroll: {
                                    appState.enrollInGroup(courseId: course.courseId, groupId: grp.groupId)
                                },
                                onClear: {
                                    appState.clearEnrollment(courseId: course.courseId)
                                }
                            )
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(course.courseId)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSniperSheet) {
            SniperConfigSheet(course: course)
        }
    }
}

private struct GroupDetailCard: View {
    @EnvironmentObject var appState: AppState
    let group: ExerciseGroup
    let courseId: String
    let isEnrolled: Bool
    let onEnroll: () -> Void
    let onClear: () -> Void
    
    private var conflictCheck: (Bool, ScheduleEvent?) {
        // If already enrolled in this exact group, don't flag conflict with itself
        if isEnrolled { return (false, nil) }
        let otherEvents = appState.schedule.filter { $0.courseId != courseId }
        return OptimizerEngine.conflictsWithSchedule(group: group, schedule: otherEvents)
    }
    
    var body: some View {
        let (hasConflict, conflictEvent) = conflictCheck
        
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        CapacityPill(free: group.spotsFree, total: group.spotsTotal)
                        
                        if group.weekType == "A" {
                            AeroBadge("Woche A", color: .purple)
                        } else if group.weekType == "B" {
                            AeroBadge("Woche B", color: .indigo)
                        }
                    }
                    
                    Text(group.name)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                        .padding(.top, 2)
                }
                Spacer()
                
                if isEnrolled {
                    Button(role: .destructive, action: onClear) {
                        Label("Austragen", systemImage: "xmark.circle.fill")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.red.opacity(0.85)))
                            .foregroundColor(.white)
                    }
                } else {
                    Button(action: onEnroll) {
                        Text("Eintragen")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(hasConflict ? Color.gray.opacity(0.4) : AeroTheme.skyBlue))
                            .foregroundColor(.white)
                    }
                }
            }
            
            // Location and Tutor
            HStack(spacing: 12) {
                Label("\(group.dayName) \(group.startTime)–\(group.endTime)", systemImage: "clock")
                if !group.room.isEmpty {
                    Label(group.room, systemImage: "mappin.and.ellipse")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            // Conflict warning if any
            if hasConflict, let ce = conflictEvent {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AeroTheme.solarOrange)
                    Text("Terminkollision mit \(ce.title) (\(ce.startTime)–\(ce.endTime))")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AeroTheme.solarOrange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 8).fill(AeroTheme.solarOrange.opacity(0.12)))
            }
        }
        .padding(14)
        .frutigerGlass(cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isEnrolled ? AeroTheme.emerald.opacity(0.8) : Color.clear, lineWidth: 1.5)
        )
    }
}

private struct SniperConfigSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    let course: Course
    
    @State private var prioritizedGroups: [ExerciseGroup] = []
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Sniper-Rangfolge festlegen")) {
                    Text("Ziehe deine bevorzugten Übungsgruppen an die Spitze. Ist Rang 1 voll, bucht der UNIBODY-Sniper blitzschnell Rang 2.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(prioritizedGroups) { grp in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(grp.name)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(grp.dayName) \(grp.startTime)–\(grp.endTime) · \(grp.spotsFree)/\(grp.spotsTotal) frei")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .onMove { indices, newOffset in
                        prioritizedGroups.move(fromOffsets: indices, toOffset: newOffset)
                    }
                }
            }
            .navigationTitle("Sniper: \(course.courseId)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Scharfstellen") {
                        appState.armSniperJob(course: course, priorities: prioritizedGroups)
                        dismiss()
                    }
                }
            }
            .onAppear {
                prioritizedGroups = course.groups
            }
        }
    }
}
