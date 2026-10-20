import Foundation

public struct ScheduleEvent: Identifiable, Codable, Hashable {
    public let id: String
    public var courseId: String?
    public var groupId: String?
    public var title: String
    public var day: Int // 0=Mo ... 4=Fr
    public var dayName: String
    public var startTime: String // "10:15"
    public var endTime: String // "11:45"
    public var room: String
    public var type: String // "lecture", "exercise", "enrolled_exercise", "manual"
    public var enabled: Bool
    public var weekType: String // "all", "A", "B"
    
    public enum CodingKeys: String, CodingKey {
        case id
        case courseId = "course_id"
        case groupId = "group_id"
        case title
        case day
        case dayName = "day_name"
        case startTime = "start_time"
        case endTime = "end_time"
        case room
        case type
        case enabled
        case weekType = "week_type"
    }
    
    public init(
        id: String = UUID().uuidString,
        courseId: String? = nil,
        groupId: String? = nil,
        title: String,
        day: Int,
        dayName: String,
        startTime: String,
        endTime: String,
        room: String = "",
        type: String = "lecture",
        enabled: Bool = true,
        weekType: String = "all"
    ) {
        self.id = id
        self.courseId = courseId
        self.groupId = groupId
        self.title = title
        self.day = day
        self.dayName = dayName
        self.startTime = startTime
        self.endTime = endTime
        self.room = room
        self.type = type
        self.enabled = enabled
        self.weekType = weekType
    }
    
    public var startMinutes: Int {
        ScheduleEvent.parseMinutes(startTime)
    }
    
    public var endMinutes: Int {
        ScheduleEvent.parseMinutes(endTime)
    }
    
    public static func parseMinutes(_ timeStr: String) -> Int {
        let parts = timeStr.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return 0 }
        return parts[0] * 60 + parts[1]
    }
}
