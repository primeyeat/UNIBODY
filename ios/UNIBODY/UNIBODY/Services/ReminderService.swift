import Foundation
import UserNotifications

/// Local notifications for assignment deadlines and enrollment openings.
/// Everything is scheduled on the device; nothing is sent to a server.
@MainActor
public final class ReminderService: ObservableObject {
    public static let shared = ReminderService()

    private static let enabledKey = "unibody_reminders_enabled"
    private static let idPrefix = "unibody-reminder-"
    /// iOS keeps at most 64 pending local notifications per app
    private static let maxPending = 60

    @Published public private(set) var isEnabled: Bool = UserDefaults.standard.bool(forKey: ReminderService.enabledKey)
    @Published public private(set) var statusText: String? = nil

    private var latestCourses: [Course] = []
    private var latestEnrolled: [String: String] = [:]

    private init() {}

    private struct Planned {
        let id: String
        let fireDate: Date
        let title: String
        let body: String
    }

    /// Parses the app's deadline strings ("2026-11-06T20:00:00", with or without UTC offset) as Europe/Berlin time.
    public static func parseDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        if raw.hasSuffix("Z") || raw.dropFirst(10).contains("+") {
            return ISO8601DateFormatter().date(from: raw)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: raw)
    }

    /// Turns reminders on (asking for permission) or off.
    public func setEnabled(_ enabled: Bool) async {
        if enabled {
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            guard granted else {
                isEnabled = false
                UserDefaults.standard.set(false, forKey: Self.enabledKey)
                statusText = "Mitteilungen sind für UNIBODY in den iOS-Einstellungen deaktiviert."
                return
            }
        }
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
        await reschedule()
    }

    /// Remembers the latest courses and bookings (for enrollment reminders) and reschedules.
    public func update(courses: [Course], enrolledGroups: [String: String]) {
        latestCourses = courses
        latestEnrolled = enrolledGroups
        Task { await reschedule() }
    }

    /// Call whenever deadlines or completion states changed.
    public func materialsChanged() {
        Task { await reschedule() }
    }

    private func plannedReminders(now: Date) -> [Planned] {
        var planned: [Planned] = []
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "de_DE")
        timeFormatter.dateFormat = "dd.MM. 'um' HH:mm 'Uhr'"

        // 1. Assignment deadlines: 24 hours and 2 hours before
        for course in CourseMaterialsService.shared.courses {
            for homework in course.homework where !homework.completed && homework.status != "submitted" {
                guard let deadline = Self.parseDate(homework.deadline), deadline > now else { continue }
                for (hours, label) in [(24, "in 24 Stunden"), (2, "in 2 Stunden")] {
                    let fireDate = deadline.addingTimeInterval(TimeInterval(-hours * 3600))
                    guard fireDate > now else { continue }
                    planned.append(Planned(
                        id: "\(Self.idPrefix)due-\(course.courseId)-\(homework.id)-\(hours)",
                        fireDate: fireDate,
                        title: "Abgabe \(label): \(course.courseId)",
                        body: "\(homework.title) – fällig \(timeFormatter.string(from: deadline))"
                    ))
                }
            }
        }

        // 2. Enrollment openings: 15 minutes before and at the start (only without a booked group)
        for course in latestCourses where !course.isLectureOnly {
            let enrolled = latestEnrolled[course.courseId] ?? latestEnrolled[course.courseId.lowercased()]
            guard enrolled == nil, let opensAt = Self.parseDate(course.enrollmentOpensAt), opensAt > now else { continue }
            let soon = opensAt.addingTimeInterval(-15 * 60)
            if soon > now {
                planned.append(Planned(
                    id: "\(Self.idPrefix)enroll-\(course.courseId)-soon",
                    fireDate: soon,
                    title: "Einschreibung in 15 Minuten: \(course.courseId)",
                    body: "\(course.title) öffnet \(timeFormatter.string(from: opensAt))."
                ))
            }
            planned.append(Planned(
                id: "\(Self.idPrefix)enroll-\(course.courseId)-open",
                fireDate: opensAt,
                title: "Einschreibung offen: \(course.courseId)",
                body: "Die Übungsgruppen für \(course.title) sind jetzt freigeschaltet."
            ))
        }

        return Array(planned.sorted { $0.fireDate < $1.fireDate }.prefix(Self.maxPending))
    }

    /// Replaces all pending UNIBODY reminders with the current plan.
    public func reschedule() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(Self.idPrefix) })

        guard isEnabled else {
            statusText = nil
            return
        }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            statusText = "Mitteilungen sind für UNIBODY in den iOS-Einstellungen deaktiviert."
            return
        }

        let planned = plannedReminders(now: Date())
        for reminder in planned {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
        statusText = planned.isEmpty ? "Keine anstehenden Erinnerungen." : "\(planned.count) Erinnerungen geplant."
    }
}
