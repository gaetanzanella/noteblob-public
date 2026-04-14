import Foundation

public struct Note: Sendable {
    public let latestChangeDate: Date?

    public init(latestChangeDate: Date?) {
        self.latestChangeDate = latestChangeDate
    }
}
