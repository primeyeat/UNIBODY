import Foundation

/// Weights and wishes used to score exercise groups (same defaults as the web app).
public struct OptimizerPreferences: Codable, Hashable {
    public var weightCompact: Double = 85      // 0...100: avoid idle gaps
    public var weightFreeDays: Double = 80     // 0...100: keep free days free
    public var weightTimeWindow: Double = 70   // 0...100: stay inside the preferred hours
    public var weightCampusBuffer: Double = 50 // 0...100: avoid tight room changes
    public var earliestTime: String = "09:30"
    public var latestTime: String = "16:30"
    public var preferredFreeDays: [Int] = [4]
    public var minBreakMinutes: Int = 15

    public init() {}
}

/// Result of scoring one exercise group against the current timetable.
public struct GroupEvaluation: Identifiable, Hashable {
    public var id: String { group.groupId }
    public let group: ExerciseGroup
    public let score: Double
    public let displayScore: Int
    public let conflict: ScheduleEvent?
    public let reasons: [String]

    public var isConflict: Bool { conflict != nil }
}

public struct OptimizerEngine {

    private static let dayNames = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]

    /// A "Woche A" and a "Woche B" event alternate and never meet; every other pairing can overlap.
    public static func weeksCanCollide(_ week1: String, _ week2: String) -> Bool {
        !((week1 == "A" && week2 == "B") || (week1 == "B" && week2 == "A"))
    }

    /// Checks if two time intervals on the same day overlap, taking A/B alternating weeks into account!
    public static func hasConflict(
        day1: Int, start1: String, end1: String, week1: String = "all",
        day2: Int, start2: String, end2: String, week2: String = "all"
    ) -> Bool {
        guard day1 == day2, weeksCanCollide(week1, week2) else { return false }

        let s1 = ScheduleEvent.parseMinutes(start1)
        let e1 = ScheduleEvent.parseMinutes(end1)
        let s2 = ScheduleEvent.parseMinutes(start2)
        let e2 = ScheduleEvent.parseMinutes(end2)

        // Strict overlap: interval 1 starts before interval 2 ends AND interval 2 starts before interval 1 ends
        return max(s1, s2) < min(e1, e2)
    }

    /// Checks if an exercise group conflicts with any active event in the user's schedule
    public static func conflictsWithSchedule(group: ExerciseGroup, schedule: [ScheduleEvent]) -> (Bool, ScheduleEvent?) {
        for event in schedule where event.enabled {
            if hasConflict(
                day1: group.day, start1: group.startTime, end1: group.endTime, week1: group.weekType,
                day2: event.day, start2: event.startTime, end2: event.endTime, week2: event.weekType
            ) {
                return (true, event)
            }
        }
        return (false, nil)
    }

    /// Scores one group against the timetable: gaps, free days, preferred hours, room changes, day load, capacity.
    /// Mirrors `evaluate_group_candidate` of the web app's optimizer.
    public static func evaluate(
        group: ExerciseGroup,
        schedule: [ScheduleEvent],
        preferences: OptimizerPreferences = OptimizerPreferences()
    ) -> GroupEvaluation {
        let start = ScheduleEvent.parseMinutes(group.startTime)
        let end = ScheduleEvent.parseMinutes(group.endTime)
        let dayName = dayNames.indices.contains(group.day) ? dayNames[group.day] : "Tag"

        let (hasHardConflict, conflictEvent) = conflictsWithSchedule(group: group, schedule: schedule)
        if hasHardConflict, let conflictEvent {
            return GroupEvaluation(
                group: group, score: -500, displayScore: 0, conflict: conflictEvent,
                reasons: ["Zeitkonflikt mit \(conflictEvent.title) (\(conflictEvent.startTime)–\(conflictEvent.endTime))"]
            )
        }

        let sameDay = schedule.filter {
            $0.enabled && $0.day == group.day && weeksCanCollide(group.weekType, $0.weekType)
        }
        let wGaps = preferences.weightCompact / 100
        let wFreeDays = preferences.weightFreeDays / 100
        let wTime = preferences.weightTimeWindow / 100
        let wCampus = preferences.weightCampusBuffer / 100

        var score = 100.0
        var reasons: [String] = []

        // 1. Free day impact or gap to the nearest block
        if sameDay.isEmpty {
            let penalty = (preferences.preferredFreeDays.contains(group.day) ? 35.0 : 22.0) * wFreeDays
            score -= penalty
            reasons.append(
                preferences.preferredFreeDays.contains(group.day)
                    ? "Belegt deinen Wunsch-freien Tag (\(dayName))"
                    : "Belegt einen bisher freien Tag (\(dayName))"
            )
        } else {
            let gaps = sameDay.compactMap { event -> Int? in
                if start >= event.endMinutes { return start - event.endMinutes }
                if event.startMinutes >= end { return event.startMinutes - end }
                return nil
            }
            let nearest = gaps.min() ?? 0
            if nearest <= 30 {
                score += 8.0 * wGaps
                reasons.append("Nahtloser Anschluss (\(nearest) Min. Pause)")
            } else if nearest <= 60 {
                score -= 8.0 * wGaps
                reasons.append("Kurze Pause (\(nearest) Min.) zum nächsten Kurs")
            } else {
                score -= min(45.0, Double(nearest - 30) * 0.25 * wGaps)
                reasons.append("Erzeugt \(nearest / 60) Std. \(nearest % 60) Min. Freistunde")
            }
        }

        // 2. Preferred time window
        let earliest = ScheduleEvent.parseMinutes(preferences.earliestTime)
        let latest = ScheduleEvent.parseMinutes(preferences.latestTime)
        if start < earliest {
            score -= min(35.0, Double(earliest - start) / 15.0 * 6.0 * wTime)
            reasons.append("Beginnt vor deiner Wunschzeit (\(preferences.earliestTime))")
        } else if end > latest {
            score -= min(35.0, Double(end - latest) / 15.0 * 6.0 * wTime)
            reasons.append("Endet nach deiner Wunschzeit (\(preferences.latestTime))")
        } else {
            reasons.append("Liegt im Wunsch-Zeitfenster")
        }

        // 3. Tight room changes
        let tight = sameDay.contains { event in
            let before = start - event.endMinutes
            let after = event.startMinutes - end
            return (before >= 0 && before < preferences.minBreakMinutes)
                || (after >= 0 && after < preferences.minBreakMinutes)
        }
        if tight && wCampus > 0 {
            score -= 10.0 * wCampus
            reasons.append("Knapper Raumwechsel (unter \(preferences.minBreakMinutes) Min.)")
        }

        // 4. Daily load above six hours
        let dayMinutes = sameDay.reduce(0) { $0 + max(0, $1.endMinutes - $1.startMinutes) } + max(0, end - start)
        if dayMinutes > 360 {
            score -= min(20.0, Double(dayMinutes - 360) / 60.0 * 8.0)
            reasons.append("Langer Uni-Tag (\(dayMinutes / 60) Std.)")
        }

        // 5. Capacity
        if group.isFull {
            score -= 40.0
            reasons.append("Aktuell voll belegt")
        }

        return GroupEvaluation(
            group: group,
            score: score,
            displayScore: max(1, min(100, Int(score.rounded()))),
            conflict: nil,
            reasons: reasons
        )
    }

    /// Scores all groups of a course and returns them best first:
    /// conflict-free before conflicting, free spots before full, then by score.
    public static func rankGroups(
        groups: [ExerciseGroup],
        currentSchedule: [ScheduleEvent],
        preferences: OptimizerPreferences = OptimizerPreferences()
    ) -> [GroupEvaluation] {
        groups
            .map { evaluate(group: $0, schedule: currentSchedule, preferences: preferences) }
            .sorted { lhs, rhs in
                if lhs.isConflict != rhs.isConflict { return !lhs.isConflict }
                if lhs.group.isFull != rhs.group.isFull { return !lhs.group.isFull }
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.group.groupId < rhs.group.groupId
            }
    }
}
