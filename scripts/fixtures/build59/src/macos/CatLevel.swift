import Foundation

// Accepted slow, stepwise progression. Each three levels add one XP to the cost.
struct CatLevelProgress {
    let level: Int
    let earnedInLevel: Int
    let requiredInLevel: Int
    init(points: Int) {
        // Same bound as saved growth; only evaluated when the panel refreshes.
        var remaining = max(0, min(2_000_000, points)), completed = 0
        while remaining >= 2 + completed / 3 {
            remaining -= 2 + completed / 3; completed += 1
        }
        level = completed; earnedInLevel = remaining; requiredInLevel = 2 + completed / 3
    }
    func unlocked(_ reward: CatGrowthReward) -> Bool { level >= Self.requiredLevel(reward) }
    static func requiredLevel(_ reward: CatGrowthReward) -> Int { [1, 5, 10][reward.rawValue] }
}

struct CatCompletionFeedback {
    private var day = 0
    private(set) var shownDay: Int
    private var pending: String?
    private var armed = false
    private var current: String?
    private var until = -Double.infinity
    private var lastVariant = -1

    init(shownDay: Int = 0) { self.shownDay = shownDay }

    // Called only by a deliberate, eligible interaction, never by resume/timer.
    mutating func record(completed: Set<CatGrowthGoal>, day: Int, companionDays: Int, at now: Double, sample: Int) {
        guard day >= self.day, day > shownDay, companionDays > 0 else { return }
        if day > self.day { cancel(); pending = nil; self.day = day }
        guard CatGrowthGoal.allCases.allSatisfy(completed.contains) else { return }
        if pending == nil {
            let lines = [
                "这是陪你玩的第 \(companionDays) 天啦。",
                "一起玩的第 \(companionDays) 天，开心。",
                "第 \(companionDays) 天啦，又和你玩了一会儿。",
                "陪你玩到第 \(companionDays) 天啦。",
                "我们的第 \(companionDays) 天，有你真好。",
                "第 \(companionDays) 天，今天也喜欢和你玩。"
            ]
            var index = max(0, sample) % lines.count
            if index == lastVariant { index = (index + 1) % lines.count }
            lastVariant = index; pending = lines[index]
        }
        armed = true
    }
    mutating func text(at now: Double, available: Bool, blocked: Bool) -> String? {
        guard available else { cancel(); return nil }
        // Contact gates the first presentation, not an already-started line.
        // Subsequent pets keep their motion but cannot replace or extend speech.
        if let current, now < until { return current }
        current = nil
        if blocked { return nil }
        guard armed, day > shownDay, let pending else { return nil }
        current = pending; until = .infinity
        return current
    }
    func isPresenting(at now:Double)->Bool {current != nil && now<until}
    // A draw acknowledgement, not merely assigning view.text, consumes the day.
    // The caller checks the real window/context and persists this local receipt.
    func awaitsRender(_ text: String) -> Bool {
        armed && day > shownDay && current == text && pending == text
    }
    mutating func didRender(_ text: String, at now: Double) -> Int? {
        guard awaitsRender(text) else { return nil }
        shownDay = day; pending = nil; until = now + 3
        return day
    }
    // Hide/rest/occlusion disarms; it cannot erase unshown eligibility.
    mutating func cancel() { armed = false; current = nil; until = -.infinity }
}
