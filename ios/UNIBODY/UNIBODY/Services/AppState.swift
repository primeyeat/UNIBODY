import SwiftUI
import Combine

@MainActor
public class AppState: ObservableObject {
    @Published public var schedule: [ScheduleEvent] = []
    @Published public var courses: [Course] = []
    @Published public var enrolledGroups: [String: String] = [:] // [course_id: group_id]
    @Published public var jobs: [SniperJob] = []
    @Published public var serverURL: String = "http://127.0.0.1:8765"
    @Published public var isSyncing: Bool = false
    @Published public var syncMessage: String? = nil
    
    // CAU Account Credentials Vault
    @Published public var username: String = ""
    @Published public var password: String = ""
    @Published public var defaultPlatform: String = "unibody" // "unibody", "openolat", "moodle"
    @Published public var isAutoFillActive: Bool = true
    @Published public var isAutoSubmitActive: Bool = true
    @Published public var isVaultSaved: Bool = false
    
    private let kUsernameKey = "unibody_cau_username"
    private let kPasswordKey = "unibody_cau_password"
    private let kPlatformKey = "unibody_cau_platform"
    private let kAutoFillKey = "unibody_cau_autofill"
    private let kAutoSubmitKey = "unibody_cau_autosubmit"
    
    @Published public var lastSyncDate: Date? = nil
    
    // Theme & Easter Egg
    @Published public var isDarkMode: Bool = true
    @Published public var showClaireEasterEgg: Bool = false
    private var themeToggleTimestamps: [Date] = []
    
    // Dynamic Island Campus Map & Room Navigator
    @Published public var activeNavEvent: ScheduleEvent? = nil
    @Published public var isDynamicIslandActive: Bool = false
    
    public func navigateToCampusRoom(for event: ScheduleEvent) {
        self.activeNavEvent = event
        self.isDynamicIslandActive = true
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
    
    public func closeCampusNavigation() {
        self.activeNavEvent = nil
        self.isDynamicIslandActive = false
    }
    
    public var nextUpcomingEvent: ScheduleEvent? {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        let dayIdx = max(0, min(4, weekday - 2))
        let eventsToday = schedule.filter { $0.day == dayIdx && $0.enabled }.sorted { $0.startMinutes < $1.startMinutes }
        return eventsToday.first ?? schedule.first(where: { $0.enabled && !$0.room.isEmpty })
    }
    
    public func toggleDarkMode() {
        isDarkMode.toggle()
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        
        let now = Date()
        themeToggleTimestamps.append(now)
        themeToggleTimestamps = themeToggleTimestamps.filter { now.timeIntervalSince($0) <= 3.5 }
        if themeToggleTimestamps.count >= 7 {
            themeToggleTimestamps.removeAll()
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            showClaireEasterEgg = true
        }
    }
    
    public init() {
        loadCredentialsFromStorage()
        loadInitialData()
        
        // Auto-sync on startup
        Task {
            await syncWithLocalServer()
        }
    }
    
    public func loadCredentialsFromStorage() {
        let defaults = UserDefaults.standard
        if let savedUser = defaults.string(forKey: kUsernameKey), !savedUser.isEmpty {
            self.username = savedUser
            self.password = defaults.string(forKey: kPasswordKey) ?? ""
            self.defaultPlatform = defaults.string(forKey: kPlatformKey) ?? "unibody"
            self.isAutoFillActive = defaults.object(forKey: kAutoFillKey) as? Bool ?? true
            self.isAutoSubmitActive = defaults.object(forKey: kAutoSubmitKey) as? Bool ?? true
            self.isVaultSaved = true
        }
    }
    
    public func saveCredentials(username: String, password: String, defaultPlatform: String = "unibody", autoFill: Bool = true, autoSubmit: Bool = true) {
        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        self.username = trimmedUser
        self.password = password
        self.defaultPlatform = defaultPlatform
        self.isAutoFillActive = autoFill
        self.isAutoSubmitActive = autoSubmit
        self.isVaultSaved = !trimmedUser.isEmpty
        
        let defaults = UserDefaults.standard
        defaults.set(trimmedUser, forKey: kUsernameKey)
        defaults.set(password, forKey: kPasswordKey)
        defaults.set(defaultPlatform, forKey: kPlatformKey)
        defaults.set(autoFill, forKey: kAutoFillKey)
        defaults.set(autoSubmit, forKey: kAutoSubmitKey)
        
        // Also sync credentials asynchronously to local backend if running
        Task {
            await syncCredentialsToServer()
        }
    }
    
    public func clearCredentials() {
        self.username = ""
        self.password = ""
        self.isVaultSaved = false
        
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: kUsernameKey)
        defaults.removeObject(forKey: kPasswordKey)
        defaults.removeObject(forKey: kPlatformKey)
        
        Task {
            guard let url = URL(string: "\(serverURL)/api/credentials/clear") else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            _ = try? await URLSession.shared.data(for: req)
        }
    }
    
    public func syncCredentialsToServer() async {
        guard let url = URL(string: "\(serverURL)/api/credentials/save") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "username": username,
            "password": password,
            "default_platform": defaultPlatform,
            "auto_fill": isAutoFillActive,
            "auto_submit": isAutoSubmitActive,
            "use_keychain": true,
            "launch_browser": false
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            req.httpBody = data
            _ = try? await URLSession.shared.data(for: req)
        }
    }
    
    public func loadInitialData() {
        // Complete CAU lectures for WiSe 2026/27
        self.schedule = [
            // MONTAG
            ScheduleEvent(
                id: "lec-infrecht-1",
                courseId: "Inf-InfRecht",
                title: "VL Inf-InfRecht [#080103]: Informatikrecht (14-tägig)",
                day: 0,
                dayName: "Montag",
                startTime: "10:15",
                endTime: "11:45",
                room: "CAP3 - Hörsaal 3",
                type: "lecture",
                enabled: true,
                weekType: "A"
            ),
            ScheduleEvent(
                id: "lec-einf-1",
                courseId: "infEInf-02a",
                title: "VL infEInf-02a/01a [#080058]: Einführung in die Informatik",
                day: 0,
                dayName: "Montag",
                startTime: "14:00",
                endTime: "16:00",
                room: "Online-Veranstaltung",
                type: "lecture",
                enabled: true
            ),
            // DIENSTAG
            ScheduleEvent(
                id: "lec-bwl-1",
                courseId: "BWL-EinfBWL",
                title: "VL BWL-EinfBWL [#030225]: Einführung in die BWL",
                day: 1,
                dayName: "Dienstag",
                startTime: "12:15",
                endTime: "13:45",
                room: "CAP3 - Hörsaal 2",
                type: "lecture",
                enabled: true
            ),
            // MITTWOCH
            ScheduleEvent(
                id: "lec-matha-1",
                courseId: "Inf-Math-A",
                title: "VL Inf-Math-A [#060107]: Mathematik für die Informatik A",
                day: 2,
                dayName: "Mittwoch",
                startTime: "08:15",
                endTime: "09:45",
                room: "CAP3 - Hörsaal 2",
                type: "lecture",
                enabled: true
            ),
            // DONNERSTAG
            ScheduleEvent(
                id: "lec-ewinf-1",
                courseId: "infEWInf-01a",
                title: "VL infEWInf-01a [#080038]: Einführung in die Wirtschaftsinformatik",
                day: 3,
                dayName: "Donnerstag",
                startTime: "10:15",
                endTime: "11:45",
                room: "LMS6 - R.11 / CAP2",
                type: "lecture",
                enabled: true
            ),
            // FREITAG
            ScheduleEvent(
                id: "lec-matha-2",
                courseId: "Inf-Math-A",
                title: "VL Inf-Math-A [#060107]: Mathematik für die Informatik A",
                day: 4,
                dayName: "Freitag",
                startTime: "10:15",
                endTime: "11:45",
                room: "OS75 - Hörsaal 1",
                type: "lecture",
                enabled: true
            ),
            ScheduleEvent(
                id: "lec-einf-2",
                courseId: "infEInf-02a",
                title: "VL infEInf-02a/01a [#080058]: Einführung in die Informatik",
                day: 4,
                dayName: "Freitag",
                startTime: "12:00",
                endTime: "14:00",
                room: "OHP5 - Chemie II",
                type: "lecture",
                enabled: true
            )
        ]
        
        // Built-in courses with realistic CAU groups
        self.courses = [
            Course(
                courseId: "Inf-InfRecht",
                univisId: "080103",
                olatRepoId: "080103",
                title: "Informatikrecht (2 LP)",
                lecturer: "Dr. Hermann Lindhorst",
                platformId: "openolat",
                platformHost: "lms.uni-kiel.de",
                platformBadge: "🏛️ lms.uni-kiel.de",
                url: "https://lms.uni-kiel.de",
                enrollmentMode: "lecture_only",
                enrollmentOpensAt: "2026-10-23T12:00:00",
                groups: []
            ),
            Course(
                courseId: "infEWInf-01a",
                univisId: "080038",
                olatRepoId: "41589955",
                title: "Einführung in die Wirtschaftsinformatik (E-Business)",
                lecturer: "Prof. Dr. Ann-Kristin Cordes",
                platformId: "openolat",
                platformHost: "lms.uni-kiel.de",
                platformBadge: "🏛️ lms.uni-kiel.de",
                url: "https://lms.uni-kiel.de/url/RepositoryEntry/41589955",
                enrollmentMode: "sniper",
                enrollmentOpensAt: "2026-10-21T12:00:00",
                groups: [
                    ExerciseGroup(groupId: "080042-g1", name: "Übung 01 (Mi 12:15–13:45 · LMS8)", day: 2, dayName: "Mittwoch", startTime: "12:15", endTime: "13:45", room: "LMS8 - R.EG.015", tutor: "Lossner / Fritzke", spotsFree: 38, spotsTotal: 40),
                    ExerciseGroup(groupId: "080042-g2", name: "Übung 02 (Do 12:15–13:45 · LMS11a)", day: 3, dayName: "Donnerstag", startTime: "12:15", endTime: "13:45", room: "LMS11a - R.EG.003", tutor: "Lossner / Fritzke", spotsFree: 40, spotsTotal: 40),
                    ExerciseGroup(groupId: "080042-g3", name: "Übung 03 (Do 14:15–15:45 · LMS8)", day: 3, dayName: "Donnerstag", startTime: "14:15", endTime: "15:45", room: "LMS8 - R.EG.010", tutor: "Lossner / Fritzke", spotsFree: 35, spotsTotal: 40),
                    ExerciseGroup(groupId: "080042-g4", name: "Übung 04 (Fr 10:15–11:45 · CAP2)", day: 4, dayName: "Freitag", startTime: "10:15", endTime: "11:45", room: "CAP2 - R.K1", tutor: "Lossner / Fritzke", spotsFree: 40, spotsTotal: 40)
                ]
            ),
            Course(
                courseId: "Inf-Math-A",
                univisId: "060107",
                olatRepoId: "5804556477",
                title: "Mathematik für die Informatik A (8 LP)",
                lecturer: "Dr. Barbara Langfeld",
                platformId: "openolat",
                platformHost: "lms.uni-kiel.de",
                platformBadge: "🏛️ lms.uni-kiel.de",
                url: "https://lms.uni-kiel.de",
                enrollmentMode: "priority",
                enrollmentOpensAt: "2026-10-19T09:00:00",
                groups: [
                    ExerciseGroup(groupId: "060098", name: "Ü:MathInfA (Di 16:15–17:45 · HHP6)", day: 1, dayName: "Dienstag", startTime: "16:15", endTime: "17:45", room: "HHP6 - R.EG.004", tutor: "UnivIS 060098", spotsFree: 13, spotsTotal: 40),
                    ExerciseGroup(groupId: "060103", name: "Ü:MathInfA (Di 16:15–17:45 · LMS4)", day: 1, dayName: "Dienstag", startTime: "16:15", endTime: "17:45", room: "LMS4 - R.424", tutor: "UnivIS 060103", spotsFree: 17, spotsTotal: 40),
                    ExerciseGroup(groupId: "060397", name: "Ü:MathInfA (Mi 14:15–15:45 · HHP6)", day: 2, dayName: "Mittwoch", startTime: "14:15", endTime: "15:45", room: "HHP6 - R.EG.004", tutor: "UnivIS 060397", spotsFree: 0, spotsTotal: 40),
                    ExerciseGroup(groupId: "060102", name: "Ü:MathInfA (Mi 16:15–17:45 · HHP6)", day: 2, dayName: "Mittwoch", startTime: "16:15", endTime: "17:45", room: "HHP6 - R.EG.004", tutor: "UnivIS 060102", spotsFree: 9, spotsTotal: 40),
                    ExerciseGroup(groupId: "060577-a", name: "Ü:MathInfA (Do 10:15–11:45 · Woche A)", day: 3, dayName: "Donnerstag", startTime: "10:15", endTime: "11:45", room: "LMS8 - R.01.025", tutor: "UnivIS 060577", spotsFree: 12, spotsTotal: 30, weekType: "A"),
                    ExerciseGroup(groupId: "060577-b", name: "Ü:MathInfA (Do 10:15–11:45 · Woche B)", day: 3, dayName: "Donnerstag", startTime: "10:15", endTime: "11:45", room: "LMS8 - R.01.025", tutor: "UnivIS 060577", spotsFree: 18, spotsTotal: 30, weekType: "B"),
                    ExerciseGroup(groupId: "060574", name: "Ü:MathInfA (Fr 12:15–13:45 · LMS8)", day: 4, dayName: "Freitag", startTime: "12:15", endTime: "13:45", room: "LMS8 - R.01.011", tutor: "UnivIS 060574", spotsFree: 15, spotsTotal: 30)
                ]
            ),
            Course(
                courseId: "infEInf-02a",
                univisId: "080058",
                olatRepoId: "moodle-einf-2026",
                title: "Einführung in die Informatik",
                lecturer: "Prof. Dr. Thomas Wilke",
                platformId: "moodle_info",
                platformHost: "elearn.informatik.uni-kiel.de",
                platformBadge: "⚡ elearn.informatik.uni-kiel.de",
                url: "https://elearn.informatik.uni-kiel.de/course/view.php?id=382",
                enrollmentMode: "priority",
                enrollmentOpensAt: "2026-10-23T10:00:00",
                groups: [
                    ExerciseGroup(groupId: "080058-g1", name: "Große Übung 01 (Di 10:15–11:45)", day: 1, dayName: "Dienstag", startTime: "10:15", endTime: "11:45", room: "CAP3 - Hörsaal 1", tutor: "Wilke", spotsFree: 85, spotsTotal: 90),
                    ExerciseGroup(groupId: "080058-g2", name: "Große Übung 02 (Mi 08:15–09:45)", day: 2, dayName: "Mittwoch", startTime: "08:15", endTime: "09:45", room: "CAP3 - Hörsaal 2", tutor: "Wilke", spotsFree: 90, spotsTotal: 90),
                    ExerciseGroup(groupId: "080056-g6", name: "Übung 06 (Do 14:15–15:45 · WSP3)", day: 3, dayName: "Donnerstag", startTime: "14:15", endTime: "15:45", room: "WSP3 - SR 2", tutor: "Wilke", spotsFree: 32, spotsTotal: 32),
                    ExerciseGroup(groupId: "080056-g7", name: "Betreutes Arbeiten (Fr 14:15–15:45)", day: 4, dayName: "Freitag", startTime: "14:15", endTime: "15:45", room: "LMS8 - R.EG.018", tutor: "Wilke", spotsFree: 40, spotsTotal: 40)
                ]
            ),
            Course(
                courseId: "BWL-EinfBWL",
                univisId: "030225",
                olatRepoId: "5846466590",
                title: "Einführung in die BWL (5 LP)",
                lecturer: "Prof. Dr. Achim Walter",
                platformId: "openolat",
                platformHost: "lms.uni-kiel.de",
                platformBadge: "🏛️ lms.uni-kiel.de",
                url: "https://lms.uni-kiel.de/auth/RepositoryEntry/5846466590",
                enrollmentMode: "sniper",
                enrollmentOpensAt: "2026-10-20T16:00:00",
                groups: [
                    ExerciseGroup(groupId: "030191", name: "EBWL Übung Gr 1 (Do 10:15–11:45 · Woche A)", day: 3, dayName: "Donnerstag", startTime: "10:15", endTime: "11:45", room: "LMS2 - R.Ü2/K", tutor: "Walter (Woche A)", spotsFree: 28, spotsTotal: 44, weekType: "A"),
                    ExerciseGroup(groupId: "030189", name: "EBWL Übung Gr 2 (Do 12:15–13:45 · Woche A)", day: 3, dayName: "Donnerstag", startTime: "12:15", endTime: "13:45", room: "LMS2 - R.Ü2/K", tutor: "Walter (Woche A)", spotsFree: 0, spotsTotal: 44, weekType: "A"),
                    ExerciseGroup(groupId: "030191-g5", name: "EBWL Übung Gr 5 (Do 10:15–11:45 · Woche B)", day: 3, dayName: "Donnerstag", startTime: "10:15", endTime: "11:45", room: "LMS2 - R.Ü2/K", tutor: "Walter (Woche B)", spotsFree: 44, spotsTotal: 44, weekType: "B"),
                    ExerciseGroup(groupId: "030189-g6", name: "EBWL Übung Gr 6 (Do 12:15–13:45 · Woche B)", day: 3, dayName: "Donnerstag", startTime: "12:15", endTime: "13:45", room: "LMS2 - R.Ü2/K", tutor: "Walter (Woche B)", spotsFree: 1, spotsTotal: 44, weekType: "B")
                ]
            )
        ]
    }
    
    public func enrollInGroup(courseId: String, groupId: String) {
        guard let course = courses.first(where: { $0.courseId == courseId }),
              let group = course.groups.first(where: { $0.groupId == groupId }) else { return }
        
        enrolledGroups[courseId] = groupId
        
        // Remove prior enrolled event for this course
        schedule.removeAll { $0.courseId == courseId && $0.type == "enrolled_exercise" }
        
        // Add newly enrolled exercise to schedule
        let newEvent = ScheduleEvent(
            id: "enrolled-\(courseId)",
            courseId: courseId,
            groupId: groupId,
            title: "✅ \(courseId): \(group.name)",
            day: group.day,
            dayName: group.dayName,
            startTime: group.startTime,
            endTime: group.endTime,
            room: group.room,
            type: "enrolled_exercise",
            enabled: true,
            weekType: group.weekType
        )
        schedule.append(newEvent)
    }
    
    /// Strictly verified async unenrollment: only removes from local state and triggers UI success if verified on the university LMS.
    public func clearEnrollmentAsync(courseId: String, force: Bool = false) async -> (success: Bool, message: String) {
        let server = serverURL
        guard let host = await SyncService.shared.discoverActiveServer(preferredURL: server) else {
            return (false, "UNIBODY Mac-Server nicht erreichbar. Bitte stelle sicher, dass UNIBODY auf deinem Rechner läuft.")
        }
        
        let result = await SyncService.shared.postUnenroll(serverURL: host, courseId: courseId, force: force)
        if result.success {
            await MainActor.run {
                let cidKey = courseId.lowercased()
                enrolledGroups.removeValue(forKey: courseId)
                enrolledGroups.removeValue(forKey: cidKey)
                schedule.removeAll {
                    ($0.courseId?.lowercased() == cidKey || $0.id.lowercased().contains(cidKey)) &&
                    $0.type == "enrolled_exercise"
                }
                for i in 0..<courses.count {
                    if courses[i].courseId.lowercased() == cidKey {
                        courses[i].enrolledGroupId = nil
                    }
                }
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
            }
        }
        return result
    }
    
    public func clearEnrollment(courseId: String) {
        let cidKey = courseId.lowercased()
        enrolledGroups.removeValue(forKey: courseId)
        enrolledGroups.removeValue(forKey: cidKey)
        schedule.removeAll {
            ($0.courseId?.lowercased() == cidKey || $0.id.lowercased().contains(cidKey)) &&
            $0.type == "enrolled_exercise"
        }
        for i in 0..<courses.count {
            if courses[i].courseId.lowercased() == cidKey {
                courses[i].enrolledGroupId = nil
            }
        }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        
        let server = serverURL
        Task {
            if let host = await SyncService.shared.discoverActiveServer(preferredURL: server) {
                _ = await SyncService.shared.postUnenroll(serverURL: host, courseId: courseId)
            }
        }
    }
    
    public func toggleEvent(id: String) {
        if let idx = schedule.firstIndex(where: { $0.id == id }) {
            schedule[idx].enabled.toggle()
        }
    }
    
    public func deleteEvent(id: String) {
        if let ev = schedule.first(where: { $0.id == id }), let cid = ev.courseId {
            enrolledGroups.removeValue(forKey: cid)
        }
        schedule.removeAll { $0.id == id }
    }
    
    public func armSniperJob(course: Course, priorities: [ExerciseGroup]) {
        let job = SniperJob(
            courseId: course.courseId,
            title: course.title,
            platformHost: course.platformHost,
            mode: course.enrollmentMode,
            status: "armed",
            targetTime: course.enrollmentOpensAt,
            priorities: priorities
        )
        jobs.insert(job, at: 0)
    }
    
    public func fetchBookedExercisesFromOnlineAccounts() async {
        guard !username.isEmpty, !password.isEmpty else {
            syncMessage = "⚠️ Bitte gib zuerst deine CAU-Kennung und dein Passwort ein."
            return
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        let results = await CAUOnlineAccountFetcher.shared.fetchBookedExercises(
            username: username,
            password: password,
            knownCourses: courses
        )
        
        for r in results {
            enrollInGroup(courseId: r.courseId, groupId: r.groupId)
        }
        
        self.lastSyncDate = Date()
        let count = results.count
        syncMessage = "✅ Online via CAU-Accounts geladen: \(count) belegte Übung\(count == 1 ? "" : "en") aktiv!"
    }
    
    public func syncWithLocalServer(customURL: String? = nil) async {
        isSyncing = true
        defer { isSyncing = false }
        
        let target = customURL ?? serverURL
        guard let activeHost = await SyncService.shared.discoverActiveServer(preferredURL: target) else {
            syncMessage = "⚠️ UNIBODY Server nicht erreichbar (\(target)). Lokaler Offline-Modus aktiv."
            return
        }
        
        self.serverURL = activeHost
        
        do {
            let result = try await SyncService.shared.fetchServerState(serverURL: activeHost)
            
            // 1. Update Enrolled Groups Map
            self.enrolledGroups = result.enrolled
            
            // 2. Update Schedule with server events (including ✅ enrolled exercises)
            if !result.schedule.isEmpty {
                self.schedule = result.schedule
            }
            
            // 3. Mark enrolled groups in the course catalog
            for i in 0..<courses.count {
                let cid = courses[i].courseId.lowercased()
                if let enrolledGid = result.enrolled[cid] {
                    courses[i].enrolledGroupId = enrolledGid
                }
            }
            
            self.lastSyncDate = Date()
            let count = result.enrolled.count
            syncMessage = "✅ Synchronisiert (\(count) gebuchte Übung\(count == 1 ? "" : "en") aktiv) · Server: \(activeHost)"
        } catch {
            syncMessage = "Fehler beim Verarbeiten der Serverdaten: \(error.localizedDescription)"
        }
    }
}
