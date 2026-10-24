import Foundation
import CoreGraphics

enum CatGrowthGoal: String, CaseIterable, Codable { case pet, play }
enum CatGrowthReward: Int, CaseIterable {
    case sageBall, flower, fish
    var threshold: Int { [2, 12, 32][rawValue] }
    var legacyThreshold: Int { [2, 6, 12][rawValue] }
}

// Pure rules; persistence and UI are separate. Calendar dates never move backward.
struct CatGrowth {
    private(set) var points = 0
    private(set) var companionDays = 0
    private(set) var completed = Set<CatGrowthGoal>()
    private(set) var day: Int
    private var earnedRewards = Set<Int>()
    private let calendar: Calendar
    init(date: Date, calendar: Calendar = .current) {
        self.calendar = calendar; day = Self.dayKey(date, calendar: calendar)
    }
    static func dayKey(_ date: Date, calendar: Calendar) -> Int {
        var civil = Calendar(identifier: .gregorian); civil.timeZone = calendar.timeZone
        let c = civil.dateComponents([.year, .month, .day], from: date)
        return c.year! * 10000 + c.month! * 100 + c.day!
    }
    init(snapshot: CatGrowthSnapshot, calendar: Calendar = .current) {
        self.calendar = calendar; points = snapshot.points; companionDays = snapshot.companionDays
        completed = snapshot.completed; day = snapshot.day
        earnedRewards = snapshot.earnedRewards
    }
    func snapshot(ballSelected: Bool, decoration: CatGrowthReward?) -> CatGrowthSnapshot {
        snapshot(ballSelected: ballSelected, decorations: Set(decoration.map { [$0] } ?? []))
    }
    func snapshot(ballSelected: Bool, decorations: Set<CatGrowthReward>) -> CatGrowthSnapshot {
        CatGrowthSnapshot(unlockedRewards: Set(CatGrowthReward.allCases.filter(unlocked).map(\.rawValue)),
                          points: points, companionDays: companionDays, completed: completed,
                          day: day, ballSelected: ballSelected, decoration: nil,
                          decorations: Set(decorations.map(\.rawValue)))
    }
    mutating func refresh(at date: Date) {
        let next = Self.dayKey(date, calendar: calendar)
        guard next > day else { return }
        day = next; completed.removeAll()
    }
    @discardableResult mutating func record(_ goal: CatGrowthGoal, at date: Date) -> Bool {
        refresh(at: date)
        guard Self.dayKey(date, calendar: calendar) == day, !completed.contains(goal), points < 2_000_000 else { return false }
        if completed.isEmpty { companionDays += 1 }
        completed.insert(goal); points += 1
        return true
    }
    func unlocked(_ reward: CatGrowthReward) -> Bool { earnedRewards.contains(reward.rawValue) || points >= reward.threshold }
}

struct CatGrowthDrag {
    private var origin: CGPoint?
    private var moved = false
    mutating func begin(_ point: CGPoint) { origin = point; moved = false }
    mutating func move(_ point: CGPoint) {
        guard let origin else { return }
        // Normalized coordinates: about 6pt at the accepted 290pt size.
        if hypot(point.x - origin.x, point.y - origin.y) >= 0.02 { moved = true }
    }
    mutating func cancel() { origin = nil; moved = false }
    mutating func release() -> Bool {
        let result = origin != nil && moved
        cancel(); return result
    }
}
