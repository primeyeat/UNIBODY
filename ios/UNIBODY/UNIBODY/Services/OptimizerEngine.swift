import Foundation

public struct OptimizerEngine {
    
    /// Checks if two time intervals on the same day overlap, taking A/B alternating weeks into account!
    public static func hasConflict(
        day1: Int, start1: String, end1: String, week1: String = "all",
        day2: Int, start2: String, end2: String, week2: String = "all"
    ) -> Bool {
        guard day1 == day2 else { return false }
        
        // If one is Woche A and the other is Woche B, they alternate bi-weekly and NEVER conflict!
        if (week1 == "A" && week2 == "B") || (week1 == "B" && week2 == "A") {
            return false
        }
        
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
    
    /// Scores and ranks candidate exercise groups for a course
    public static func rankGroups(
        groups: [ExerciseGroup],
        currentSchedule: [ScheduleEvent],
        preferMorning: Bool = true,
        preferConsecutive: Bool = true
    ) -> [ExerciseGroup] {
        return groups.sorted { g1, g2 in
            let (c1, _) = conflictsWithSchedule(group: g1, schedule: currentSchedule)
            let (c2, _) = conflictsWithSchedule(group: g2, schedule: currentSchedule)
            
            // Conflict-free groups strictly precede conflicting ones
            if !c1 && c2 { return true }
            if c1 && !c2 { return false }
            
            // Free spots precede full ones
            if !g1.isFull && g2.isFull { return true }
            if g1.isFull && !g2.isFull { return false }
            
            // Time preference
            let m1 = ScheduleEvent.parseMinutes(g1.startTime)
            let m2 = ScheduleEvent.parseMinutes(g2.startTime)
            if preferMorning {
                return m1 < m2
            } else {
                return m1 > m2
            }
        }
    }
}
