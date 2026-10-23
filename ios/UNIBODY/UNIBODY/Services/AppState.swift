import SwiftUI
import Combine

@MainActor
public class AppState: ObservableObject {
    @Published public var schedule: [ScheduleEvent] = []
    @Published public var courses: [Course] = []
    @Published public var enrolledGroups: [String: String] = [:] // [course_id: group_id]
    @Published public var jobs: [SniperJob] = []
    @Published public var isSyncing: Bool = false
    @Published public var syncMessage: String? = nil
    
    // UNIBODY Deep-Sync Live Crawler
    @Published public var showLiveDeepSyncSheet: Bool = false
    @Published public var isDeepSyncing: Bool = false
    @Published public var deepSyncMessage: String? = nil
    
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
        } else {
            self.username = ""
            self.password = ""
            self.isVaultSaved = false
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
    }
    
    public func clearCredentials() {
        self.username = ""
        self.password = ""
        self.isVaultSaved = false
        
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: kUsernameKey)
        defaults.removeObject(forKey: kPasswordKey)
        defaults.removeObject(forKey: kPlatformKey)
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
                url: "https://lms.uni-kiel.de/url/RepositoryEntry/5804556477",
                enrollmentMode: "sniper",
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
                enrollmentMode: "sniper",
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
    
    public func enrollInGroup(
        courseId: String,
        groupId: String,
        customName: String? = nil,
        day: Int? = nil,
        dayName: String? = nil,
        startTime: String? = nil,
        endTime: String? = nil,
        room: String? = nil,
        weekType: String? = nil
    ) {
        let cidKey = courseId.lowercased()
        enrolledGroups[courseId] = groupId
        enrolledGroups[cidKey] = groupId
        
        // Remove prior enrolled event for this course
        schedule.removeAll {
            ($0.courseId?.lowercased() == cidKey || $0.courseId == courseId || $0.id.lowercased().contains(cidKey)) &&
            $0.type == "enrolled_exercise"
        }
        
        for i in 0..<courses.count {
            if courses[i].courseId.lowercased() == cidKey || courses[i].courseId == courseId {
                courses[i].enrolledGroupId = groupId
            }
        }
        
        let course = courses.first(where: { $0.courseId.lowercased() == cidKey || $0.courseId == courseId })
        let group = course?.groups.first(where: { $0.groupId == groupId })
        
        let resolvedDay = group?.day ?? day ?? 0
        let resolvedDayName = group?.dayName ?? dayName ?? "Montag"
        let resolvedStart = group?.startTime ?? startTime ?? "10:15"
        let resolvedEnd = group?.endTime ?? endTime ?? "11:45"
        let resolvedRoom = group?.room ?? room ?? "CAU Campus"
        let resolvedName = group?.name ?? customName ?? "Übungsgruppe"
        let resolvedWeek = group?.weekType ?? weekType ?? "all"
        let courseTitle = course?.courseId ?? courseId
        
        // Add newly enrolled exercise to schedule
        let newEvent = ScheduleEvent(
            id: "enrolled-\(courseTitle)",
            courseId: courseTitle,
            groupId: groupId,
            title: "✅ \(courseTitle): \(resolvedName)",
            day: resolvedDay,
            dayName: resolvedDayName,
            startTime: resolvedStart,
            endTime: resolvedEnd,
            room: resolvedRoom,
            type: "enrolled_exercise",
            enabled: true,
            weekType: resolvedWeek
        )
        schedule.append(newEvent)
        
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
    
    /// Real-time live enrollment directly on the iPhone using native on-device WebKit automation
    @MainActor
    public func enrollInGroupAsync(courseId: String, groupId: String, force: Bool = false) async -> (success: Bool, message: String) {
        guard let course = courses.first(where: { $0.courseId.lowercased() == courseId.lowercased() || $0.courseId == courseId }),
              let group = course.groups.first(where: { $0.groupId == groupId }) else {
            return (false, "Kurs oder Gruppe nicht im Katalog gefunden.")
        }
        
        // 1. Force mode: immediately enroll locally in timetable
        if force {
            enrollInGroup(courseId: course.courseId, groupId: groupId)
            return (true, "Gruppe direkt im Wochenplan gebucht (Offline-Modus).")
        }
        
        // 2. Credentials check
        let user = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let pass = password
        
        // 3. Execute native on-device mobile enrollment directly on the iPhone!
        let result = await LMSMobileEngine.shared.enroll(
            course: course,
            group: group,
            username: user,
            password: pass
        )
        
        if result.success {
            enrollInGroup(courseId: course.courseId, groupId: groupId)
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            return (true, result.message)
        } else {
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            #endif
            return (false, result.message)
        }
    }
    
    /// Strictly verified async unenrollment directly on the iPhone using native on-device WebKit automation
    @MainActor
    public func clearEnrollmentAsync(courseId: String, force: Bool = false) async -> (success: Bool, message: String) {
        guard let course = courses.first(where: { $0.courseId.lowercased() == courseId.lowercased() || $0.courseId == courseId }) else {
            clearEnrollment(courseId: courseId)
            return (true, "Aus Wochenplan entfernt.")
        }
        
        if force {
            clearEnrollment(courseId: course.courseId)
            return (true, "Erfolgreich aus dem Wochenplan entfernt.")
        }
        
        let user = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let pass = password
        
        let enrolledGid = enrolledGroups[course.courseId] ?? enrolledGroups[course.courseId.lowercased()]
        let grp = course.groups.first(where: { $0.groupId == enrolledGid })
        
        let result = await LMSMobileEngine.shared.unenroll(
            course: course,
            group: grp,
            username: user,
            password: pass
        )
        
        if result.success {
            clearEnrollment(courseId: course.courseId)
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            return (true, result.message)
        } else {
            return (false, result.message)
        }
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
    
    /// Triggers the interactive On-Device UNIBODY Deep-Sync Sheet.
    /// Opens a mini browser window on the iPhone that navigates through OpenOlat ("Meine Gruppen")
    /// and Moodle, live-scrapes all booked exercise groups, and imports them directly into the weekly timetable.
    public func performDeepSync(forceOnDevice: Bool = true) {
        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUser.isEmpty, !password.isEmpty else {
            deepSyncMessage = "⚠️ Bitte trage zuerst deine CAU-Kennung und dein Passwort im Tab 'Login & Tresor' ein."
            syncMessage = deepSyncMessage
            return
        }
        
        // Wipe old/faulty enrolled exercise events so only verified bookings are scheduled
        schedule.removeAll { $0.type == "enrolled_exercise" }
        enrolledGroups.removeAll()
        for i in 0..<courses.count {
            courses[i].enrolledGroupId = nil
        }
        
        self.showLiveDeepSyncSheet = true
    }
    
    public func fetchBookedExercisesFromOnlineAccounts() async {
        performDeepSync()
    }
}
