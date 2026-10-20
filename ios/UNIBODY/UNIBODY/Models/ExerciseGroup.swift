import Foundation

public struct ExerciseGroup: Identifiable, Codable, Hashable {
    public var id: String { groupId }
    public let groupId: String
    public let name: String
    public let day: Int
    public let dayName: String
    public let startTime: String
    public let endTime: String
    public let room: String
    public let tutor: String
    public var spotsFree: Int
    public var spotsTotal: Int
    public var waitlistAvailable: Bool
    public var weekType: String // "all", "A", "B"
    
    public enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case name
        case day
        case dayName = "day_name"
        case startTime = "start_time"
        case endTime = "end_time"
        case room
        case tutor
        case spotsFree = "spots_free"
        case spotsTotal = "spots_total"
        case waitlistAvailable = "waitlist_available"
        case weekType = "week_type"
    }
    
    public init(
        groupId: String,
        name: String,
        day: Int,
        dayName: String,
        startTime: String,
        endTime: String,
        room: String,
        tutor: String = "",
        spotsFree: Int = 30,
        spotsTotal: Int = 30,
        waitlistAvailable: Bool = true,
        weekType: String = "all"
    ) {
        self.groupId = groupId
        self.name = name
        self.day = day
        self.dayName = dayName
        self.startTime = startTime
        self.endTime = endTime
        self.room = room
        self.tutor = tutor
        self.spotsFree = spotsFree
        self.spotsTotal = spotsTotal
        self.waitlistAvailable = waitlistAvailable
        self.weekType = weekType
    }
    
    public var isFull: Bool {
        spotsFree <= 0
    }
    
    public var fillRatio: Double {
        guard spotsTotal > 0 else { return 0 }
        return Double(spotsTotal - spotsFree) / Double(spotsTotal)
    }
}
