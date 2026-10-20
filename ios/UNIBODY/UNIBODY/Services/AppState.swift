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
    
    public init() {
        loadInitialData()
    }
    
    public func loadInitialData() {
        // Built-in CAU lectures
        self.schedule = [
            ScheduleEvent(
                id: "lec-einf-1",
                courseId: "infEInf-02a",
                title: "VL infEInf-02a [#080058]: Einführung in die Informatik",
                day: 0,
                dayName: "Montag",
                startTime: "14:00",
                endTime: "16:00",
                room: "Online-Veranstaltung",
                type: "lecture",
                enabled: true
            ),
            ScheduleEvent(
                id: "lec-bwl-1",
                courseId: "BWL-EinfBWL",
                title: "VL BWL-EinfBWL [#030225]: Einführung in die BWL",
                day: 1,
                dayName: "Dienstag",
                startTime: "08:15",
                endTime: "09:45",
                room: "CAP2 - Frederik-Paulsen-Hörsaal",
                type: "lecture",
                enabled: true
            ),
            ScheduleEvent(
                id: "lec-math-1",
                courseId: "MathInfA",
                title: "VL MathInfA [#060397]: Mathematik für Informatik A",
                day: 1,
                dayName: "Dienstag",
                startTime: "12:15",
                endTime: "13:45",
                room: "LMS8 - R.EG.010",
                type: "lecture",
                enabled: true
            ),
            ScheduleEvent(
                id: "lec-winf-1",
                courseId: "infewinf-01a",
                title: "VL infewinf-01a [#080038]: Grundlagen der Wirtschaftsinformatik",
                day: 3,
                dayName: "Donnerstag",
                startTime: "10:15",
                endTime: "11:45",
                room: "OHP5 - Chemie II",
                type: "lecture",
                enabled: true
            )
        ]
        
        // Built-in courses with realistic CAU groups
        self.courses = [
            Course(
                courseId: "infewinf-01a",
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
                courseId: "MathInfA",
                univisId: "060397",
                olatRepoId: "39871142",
                title: "Mathematik für Informatiker A",
                lecturer: "Prof. Dr. Anand Srivastav",
                platformId: "openolat",
                platformHost: "lms.uni-kiel.de",
                platformBadge: "🏛️ lms.uni-kiel.de",
                url: "https://lms.uni-kiel.de",
                enrollmentMode: "sniper",
                enrollmentOpensAt: "2026-10-21T10:00:00",
                groups: [
                    ExerciseGroup(groupId: "060397-g1", name: "Ü:MathInfA Gr 01 (Mi 14:15–15:45)", day: 2, dayName: "Mittwoch", startTime: "14:15", endTime: "15:45", room: "LMS8 - R.01.011", tutor: "Srivastav", spotsFree: 0, spotsTotal: 30),
                    ExerciseGroup(groupId: "060397-g2", name: "Ü:MathInfA Gr 02 (Do 08:15–09:45)", day: 3, dayName: "Donnerstag", startTime: "08:15", endTime: "09:45", room: "LMS8 - R.01.019", tutor: "Srivastav", spotsFree: 6, spotsTotal: 30),
                    ExerciseGroup(groupId: "060397-g3a", name: "Ü:MathInfA Gr 03 (Do 10:15–11:45 · Woche A)", day: 3, dayName: "Donnerstag", startTime: "10:15", endTime: "11:45", room: "LMS8 - R.01.025", tutor: "Srivastav", spotsFree: 12, spotsTotal: 30, weekType: "A"),
                    ExerciseGroup(groupId: "060397-g3b", name: "Ü:MathInfA Gr 04 (Do 10:15–11:45 · Woche B)", day: 3, dayName: "Donnerstag", startTime: "10:15", endTime: "11:45", room: "LMS8 - R.01.025", tutor: "Srivastav", spotsFree: 18, spotsTotal: 30, weekType: "B"),
                    ExerciseGroup(groupId: "060397-g5", name: "Ü:MathInfA Gr 05 (Fr 12:15–13:45)", day: 4, dayName: "Freitag", startTime: "12:15", endTime: "13:45", room: "LMS8 - R.01.011", tutor: "Srivastav", spotsFree: 15, spotsTotal: 30)
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
                    ExerciseGroup(groupId: "080058-g3", name: "Große Übung 03 (Fr 14:15–15:45)", day: 4, dayName: "Freitag", startTime: "14:15", endTime: "15:45", room: "CAP3 - Hörsaal 1", tutor: "Wilke", spotsFree: 72, spotsTotal: 90)
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
    
    public func clearEnrollment(courseId: String) {
        enrolledGroups.removeValue(forKey: courseId)
        schedule.removeAll { $0.courseId == courseId && $0.type == "enrolled_exercise" }
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
    
    public func syncWithLocalServer() async {
        isSyncing = true
        defer { isSyncing = false }
        
        guard let url = URL(string: "\(serverURL)/api/state") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let ok = json["ok"] as? Bool, ok {
                syncMessage = "Erfolgreich mit UNIBODY-Core synchronisiert!"
            }
        } catch {
            syncMessage = "Offline-Modus aktiv (Lokales UNIBODY-Backend nicht erreichbar)."
        }
    }
}
