import SwiftUI

public struct CourseDetailView: View {
    @EnvironmentObject var appState: AppState
    public let course: Course
    
    @State private var showSniperSheet = false
    @State private var showUnenrollSheet = false
    @State private var isUnenrolling = false
    @State private var showUnenrollError = false
    @State private var unenrollErrorMessage = ""
    @State private var unenrolledInfo: (course: String, group: String, time: String, room: String)? = nil
    
    // Live Enrollment state
    @State private var enrollingGroupId: String? = nil
    @State private var showEnrollSheet = false
    @State private var showEnrollError = false
    @State private var enrollErrorMessage = ""
    @State private var enrolledInfo: (course: String, group: String, time: String, room: String)? = nil
    @State private var pendingEnrollGroup: ExerciseGroup? = nil
    
    private var enrolledGroupId: String? {
        appState.enrolledGroups[course.courseId] ?? appState.enrolledGroups[course.courseId.lowercased()]
    }
    
    private func triggerEnroll(grp: ExerciseGroup) {
        guard enrollingGroupId == nil else { return }
        enrollingGroupId = grp.groupId
        let title = course.title
        let gName = grp.name
        let time = "\(grp.dayName), \(grp.startTime)–\(grp.endTime) Uhr"
        let room = grp.room
        
        Task {
            let result = await appState.enrollInGroupAsync(courseId: course.courseId, groupId: grp.groupId)
            await MainActor.run {
                enrollingGroupId = nil
                if result.success {
                    enrolledInfo = (course: title, group: gName, time: time, room: room)
                    showEnrollSheet = true
                } else {
                    enrollErrorMessage = result.message
                    pendingEnrollGroup = grp
                    showEnrollError = true
                }
            }
        }
    }
    
    private func triggerUnenroll(grp: ExerciseGroup) {
        guard !isUnenrolling else { return }
        isUnenrolling = true
        let title = course.title
        let gName = grp.name
        let time = "\(grp.dayName), \(grp.startTime)–\(grp.endTime) Uhr"
        let room = grp.room
        
        Task {
            let result = await appState.clearEnrollmentAsync(courseId: course.courseId)
            await MainActor.run {
                isUnenrolling = false
                if result.success {
                    unenrolledInfo = (course: title, group: gName, time: time, room: room)
                    showUnenrollSheet = true
                } else {
                    unenrollErrorMessage = result.message
                    showUnenrollError = true
                }
            }
        }
    }
    
    public var body: some View {
        ZStack {
            AeroBackgroundView()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            AeroBadge(course.platformHost, icon: course.platformId == "openolat" ? "building.columns.fill" : "bolt.fill")
                            if course.isLectureOnly {
                                AeroBadge("Reine Vorlesung", color: AeroTheme.skyBlue)
                            } else {
                                AeroBadge(course.enrollmentMode == "sniper" ? "Sniper FCFS" : "Prioritäten", color: AeroTheme.solarOrange)
                            }
                        }
                        
                        Text(course.title)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundColor(.primary)
                        
                        if !course.lecturer.isEmpty {
                            Text("Dozent: \(course.lecturer)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Image(systemName: course.isLectureOnly ? "checkmark.shield.fill" : "timer")
                                .font(.caption2)
                            Text(course.isLectureOnly ? "Keine Anmeldung erforderlich · Freie Belegung" : "Anmeldebeginn: \(course.enrollmentOpensAt.replacingOccurrences(of: "T", with: " um ")) Uhr")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundColor(AeroTheme.skyBlue)
                        .padding(.top, 4)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frutigerGlass(cornerRadius: 18)
                    
                    if course.isLectureOnly {
                        VStack(spacing: 10) {
                            Image(systemName: "info.circle")
                                .font(.title2)
                                .foregroundColor(AeroTheme.skyBlue)
                            Text("Dieses Modul besteht ausschließlich aus Vorlesungen. Es gibt keine separaten Übungsgruppen.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .frutigerGlass(cornerRadius: 16)
                    } else {
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
                    }
                    
                    // Active Enrolled Group Banner with Unenroll Option
                    if let gid = enrolledGroupId, let grp = course.groups.first(where: { $0.groupId.lowercased() == gid.lowercased() }) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(AeroTheme.emerald)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text("Aktiv gebucht & bestätigt")
                                            .font(.caption2.weight(.bold))
                                            .foregroundColor(AeroTheme.emerald)
                                        AeroBadge("LMS", color: AeroTheme.emerald)
                                    }
                                    Text(grp.name)
                                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    triggerUnenroll(grp: grp)
                                } label: {
                                    if isUnenrolling {
                                        HStack(spacing: 6) {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.7)
                                            Text("Prüfe Abmeldung...")
                                        }
                                        .font(.caption.weight(.bold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(Color.orange.opacity(0.85)))
                                        .foregroundColor(.white)
                                    } else {
                                        Label("Austragen", systemImage: "xmark.circle.fill")
                                            .font(.caption.weight(.bold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Capsule().fill(Color.red.opacity(0.85)))
                                            .foregroundColor(.white)
                                    }
                                }
                                .disabled(isUnenrolling)
                            }
                            
                            HStack(spacing: 12) {
                                Label("\(grp.dayName) \(grp.startTime)–\(grp.endTime)", systemImage: "clock")
                                if !grp.room.isEmpty {
                                    Button {
                                        CampusLocationEngine.openInAppleMaps(for: grp.room)
                                    } label: {
                                        Label(grp.room, systemImage: "mappin.and.ellipse")
                                    }
                                    .buttonStyle(.plain)
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
                    
                    // Groups List
                    LazyVStack(spacing: 12) {
                        ForEach(course.groups) { grp in
                            GroupDetailCard(
                                group: grp,
                                courseId: course.courseId,
                                isEnrolled: enrolledGroupId?.lowercased() == grp.groupId.lowercased(),
                                isUnenrolling: isUnenrolling && enrolledGroupId?.lowercased() == grp.groupId.lowercased(),
                                isEnrolling: enrollingGroupId == grp.groupId,
                                onEnroll: {
                                    triggerEnroll(grp: grp)
                                },
                                onClear: {
                                    triggerUnenroll(grp: grp)
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
        // Unenrollment Alerts & Sheets
        .alert("Austragung nicht bestätigt", isPresented: $showUnenrollError) {
            Button("OK", role: .cancel) { }
            Button("Nur aus Stundenplan entfernen", role: .destructive) {
                Task {
                    _ = await appState.clearEnrollmentAsync(courseId: course.courseId, force: true)
                }
            }
        } message: {
            Text(unenrollErrorMessage.isEmpty ? "Die Austragung konnte auf dem LMS nicht verifiziert werden. Google Chrome bleibt geöffnet." : "\(unenrollErrorMessage)\n\nGoogle Chrome bleibt zur manuellen Überprüfung geöffnet.")
        }
        .sheet(isPresented: $showUnenrollSheet) {
            if let info = unenrolledInfo {
                UnenrollSuccessModalView(
                    courseTitle: info.course,
                    groupName: info.group,
                    timeSlot: info.time,
                    room: info.room,
                    platformHost: course.platformHost
                )
                .presentationDetents([.fraction(0.58), .medium])
            }
        }
        // Enrollment Alerts & Sheets
        .alert("Einschreibung nicht bestätigt", isPresented: $showEnrollError) {
            Button("Abbrechen", role: .cancel) { }
            Button("Trotzdem im Wochenplan vormerken") {
                if let grp = pendingEnrollGroup {
                    Task {
                        _ = await appState.enrollInGroupAsync(courseId: course.courseId, groupId: grp.groupId, force: true)
                    }
                }
            }
        } message: {
            Text(enrollErrorMessage.isEmpty ? "Die Einschreibung konnte auf dem LMS nicht verifiziert werden. Google Chrome bleibt geöffnet." : "\(enrollErrorMessage)\n\nGoogle Chrome bleibt zur manuellen Überprüfung geöffnet.")
        }
        .sheet(isPresented: $showEnrollSheet) {
            if let info = enrolledInfo {
                EnrollSuccessModalView(
                    courseTitle: info.course,
                    groupName: info.group,
                    timeSlot: info.time,
                    room: info.room,
                    platformHost: course.platformHost
                )
                .presentationDetents([.fraction(0.60), .medium])
            }
        }
        .sheet(isPresented: $showSniperSheet) {
            SniperConfigSheet(course: course, onDirectEnroll: { grp in
                triggerEnroll(grp: grp)
            })
        }
    }
}

private struct GroupDetailCard: View {
    @EnvironmentObject var appState: AppState
    let group: ExerciseGroup
    let courseId: String
    let isEnrolled: Bool
    var isUnenrolling: Bool = false
    var isEnrolling: Bool = false
    let onEnroll: () -> Void
    let onClear: () -> Void
    
    private var conflictCheck: (Bool, ScheduleEvent?) {
        if isEnrolled { return (false, nil) }
        let otherEvents = appState.schedule.filter { $0.courseId?.lowercased() != courseId.lowercased() }
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
                        if isUnenrolling {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.7)
                                Text("Prüfe Abmeldung...")
                            }
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.orange.opacity(0.85)))
                            .foregroundColor(.white)
                        } else {
                            Label("Austragen", systemImage: "xmark.circle.fill")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.red.opacity(0.85)))
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(isUnenrolling)
                } else {
                    Button(action: onEnroll) {
                        if isEnrolling {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.7)
                                Text("Trage ein...")
                            }
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(AeroTheme.emerald.opacity(0.85)))
                            .foregroundColor(.white)
                        } else {
                            Text("Eintragen")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(hasConflict ? Color.gray.opacity(0.4) : AeroTheme.skyBlue))
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(isEnrolling)
                }
            }
            
            // Location and Tutor
            HStack(spacing: 12) {
                Label("\(group.dayName) \(group.startTime)–\(group.endTime)", systemImage: "clock")
                if !group.room.isEmpty {
                    Button {
                        CampusLocationEngine.openInAppleMaps(for: group.room)
                    } label: {
                        Label(group.room, systemImage: "mappin.and.ellipse")
                    }
                    .buttonStyle(.plain)
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
    var onDirectEnroll: ((ExerciseGroup) -> Void)? = nil
    
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
                
                if let topGrp = prioritizedGroups.first {
                    Section {
                        Button {
                            dismiss()
                            onDirectEnroll?(topGrp)
                        } label: {
                            HStack {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(AeroTheme.emerald)
                                Text("⚡️ Jetzt sofort live buchen (Rang 1)")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } footer: {
                        Text("Trägt dich sekundengenau live über den Browser in deine Wunsch-Übung ein.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
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

// MARK: - Enrollment Confirmation Modal View
private struct EnrollSuccessModalView: View {
    @Environment(\.dismiss) var dismiss
    let courseTitle: String
    let groupName: String
    let timeSlot: String
    let room: String
    let platformHost: String
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.02, green: 0.07, blue: 0.14).ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Header Icon
                    ZStack {
                        Circle()
                            .fill(AeroTheme.emerald.opacity(0.18))
                            .frame(width: 80, height: 80)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 40))
                            .foregroundColor(AeroTheme.emerald)
                    }
                    .padding(.top, 10)
                    
                    VStack(spacing: 6) {
                        Text("Live-Einschreibung erfolgreich!")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundColor(.white)
                        
                        Text("Direkt im Hochschulsystem (\(platformHost)) gebucht & verifiziert")
                            .font(.caption)
                            .foregroundColor(AeroTheme.emerald)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Detail Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            AeroBadge("LMS-Bestätigt", color: AeroTheme.emerald)
                            Spacer()
                            Text(platformHost)
                                .font(.caption2.weight(.medium))
                                .foregroundColor(.secondary)
                        }
                        
                        Text(courseTitle)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        Text(groupName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AeroTheme.skyBlue)
                        
                        Divider().background(Color.white.opacity(0.15))
                        
                        VStack(spacing: 8) {
                            HStack {
                                Label("Gebuchter Termin:", systemImage: "calendar.badge.clock")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(timeSlot)
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.white)
                            }
                            
                            if !room.isEmpty {
                                HStack {
                                    Label("Gebäude / Raum:", systemImage: "mappin.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(room)
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(.white)
                                }
                            }
                            
                            HStack {
                                Label("Status:", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Fest im Wochenplan eingetragen")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(AeroTheme.emerald)
                            }
                        }
                    }
                    .padding(16)
                    .frutigerGlass(cornerRadius: 16)
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("Im Wochenplan ansehen")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .glossyButton(gradient: AeroTheme.auroraGradient, cornerRadius: 14)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Unenrollment Confirmation Modal View
private struct UnenrollSuccessModalView: View {
    @Environment(\.dismiss) var dismiss
    let courseTitle: String
    let groupName: String
    let timeSlot: String
    let room: String
    let platformHost: String
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.02, green: 0.07, blue: 0.14).ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Header Icon
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.18))
                            .frame(width: 80, height: 80)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 40))
                            .foregroundColor(AeroTheme.solarOrange)
                    }
                    .padding(.top, 10)
                    
                    VStack(spacing: 6) {
                        Text("Erfolgreich ausgetragen")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundColor(.white)
                        
                        Text("Die Abmeldung wurde im Hochschulsystem verifiziert.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Detail Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            AeroBadge("LMS-Freigegeben", color: AeroTheme.solarOrange)
                            Spacer()
                            Text(platformHost)
                                .font(.caption2.weight(.medium))
                                .foregroundColor(.secondary)
                        }
                        
                        Text(courseTitle)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        Text(groupName)
                            .font(.subheadline)
                            .foregroundColor(AeroTheme.solarOrange)
                        
                        Divider().background(Color.white.opacity(0.15))
                        
                        VStack(spacing: 8) {
                            HStack {
                                Label("Freigegebener Slot:", systemImage: "calendar.badge.clock")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(timeSlot)
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.white)
                            }
                            
                            if !room.isEmpty {
                                HStack {
                                    Label("Bisheriger Raum:", systemImage: "mappin.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(room)
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(.white)
                                }
                            }
                            
                            HStack {
                                Label("Status:", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Im Wochenplan freigegeben")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(AeroTheme.emerald)
                            }
                        }
                    }
                    .padding(16)
                    .frutigerGlass(cornerRadius: 16)
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("Fertig")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .glossyButton(gradient: AeroTheme.oceanGradient, cornerRadius: 14)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
    }
}
