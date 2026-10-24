import Foundation

@main struct LevelFeedbackTests {
    static func main() {
        func check(_ result: Bool, _ message: String) { if !result { fputs("FAIL: \(message)\n", stderr); exit(1) } }
        let expected: [(Int, Int, Int, Int)] = [(0,0,0,2),(1,0,1,2),(2,1,0,2),(4,2,0,2),(5,2,1,2),(6,3,0,3),(8,3,2,3),(9,4,0,3),(11,4,2,3),(12,5,0,3),(15,6,0,4),(19,7,0,4),(23,8,0,4),(27,9,0,5),(31,9,4,5),(32,10,0,5),(37,11,0,5),(42,12,0,6)]
        for (points, level, earned, required) in expected {
            let p = CatLevelProgress(points: points)
            check(p.level == level && p.earnedInLevel == earned && p.requiredInLevel == required, "real earned XP must produce level/progress at \(points), including exact crossings")
        }
        for (points, rewards) in [(0,0),(1,0),(2,1),(6,1),(8,1),(11,1),(12,2),(17,2),(31,2),(32,3)] {
            check(CatGrowthReward.allCases.filter { CatLevelProgress(points: points).unlocked($0) }.count == rewards, "level-gated rewards unlock at 2/12/32 XP for levels 1/5/10")
        }
        let all: Set<CatGrowthGoal> = [.pet, .play]
        var feedback = CatCompletionFeedback()
        feedback.record(completed: [.pet], day: 20261018, companionDays: 7, at: 0, sample: 0)
        check(feedback.text(at: 1, available: true, blocked: false) == nil, "one goal never creates a completion line")
        feedback.record(completed: all, day: 20261018, companionDays: 7, at: 10, sample: 0)
        check(feedback.text(at: 10.1, available: true, blocked: true) == nil, "completion waits for the existing interaction/bubble")
        let first = feedback.text(at: 12, available: true, blocked: false)
        check(first?.contains("第 7 天") == true, "first completion mentions cumulative interaction day")
        check(feedback.didRender(first!, at: 12) == 20261018, "only rendering consumes the day")
        check(feedback.text(at: 14.9, available: true, blocked: false) == first, "line stays readable for three seconds without reselecting")
        check(feedback.text(at: 15.1, available: true, blocked: false) == nil, "line ends without looping")
        for _ in 0..<10 { feedback.record(completed: all, day: 20261018, companionDays: 7, at: 20, sample: 3) }
        check(feedback.text(at: 20, available: true, blocked: false) == nil, "repeated full-goal state cannot create another daily line")
        feedback.record(completed: [.play], day: 20261019, companionDays: 8, at: 30, sample: 0)
        check(feedback.text(at: 30, available: true, blocked: false) == nil, "play-first also waits for both goals")
        feedback.record(completed: all, day: 20261019, companionDays: 8, at: 31, sample: 0)
        let second = feedback.text(at: 31, available: true, blocked: false)
        check(second?.contains("第 8 天") == true && second != first?.replacingOccurrences(of: "7", with: "8"), "new day keeps day emphasis but avoids last wording")
        _ = feedback.didRender(second!, at: 31)
        check(feedback.text(at: 32, available: true, blocked: true) == second && feedback.text(at: 33, available: true, blocked: false) == second, "new input cannot interrupt a visible completion")
        check(feedback.text(at:34.1,available:true,blocked:false)==nil,"continued interaction cannot extend or replay completion")
        feedback.record(completed: all, day: 20261020, companionDays: 9, at: 40, sample: 2)
        check(feedback.text(at: 41, available: false, blocked: false) == nil, "hide/rest cancels pending feedback")
        check(feedback.text(at: 42, available: true, blocked: false) == nil, "resume never replays a cancelled line")
        feedback.record(completed: all, day: 20261020, companionDays: 9, at: 43, sample: 2)
        check(feedback.text(at: 44, available: true, blocked: false) != nil, "deliberate input retries a cancelled but unshown line")
        feedback.record(completed: all, day: 20261021, companionDays: 10, at: 50, sample: 2)
        let delayed = feedback.text(at: 71, available: true, blocked: false)!
        check(delayed.contains("第 10 天"), "busy waiting never expires today's unshown line")
        _ = feedback.didRender(delayed, at: 71)
        feedback.cancel()
        feedback.record(completed: all, day: 20261020, companionDays: 9, at: 72, sample: 3)
        check(feedback.text(at: 72, available: true, blocked: false) == nil, "clock rollback cannot earn another old-day line")
        var restarted = CatCompletionFeedback()
        check(restarted.text(at: 70, available: true, blocked: false) == nil, "new process has no pending speech")
        var day = CatGrowth(date: Date(timeIntervalSince1970: 1_800_000_000))
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        day.record(.pet, at: start); day.record(.play, at: start)
        day.record(.play, at: start.addingTimeInterval(86400 * 9))
        check(day.companionDays == 2, "nine absent days do not inflate cumulative interaction days")
        for sample in 0..<6 {
            var f = CatCompletionFeedback(); f.record(completed: all, day: 20261020, companionDays: 123, at: 0, sample: sample)
            let line = f.text(at: 0, available: true, blocked: false)!
            check(line.contains("第 123 天") && line.count <= 24, "all variants retain the day and fit the existing bubble contract")
        }
        var queued = CatCompletionFeedback()
        queued.record(completed: all, day: 20261020, companionDays: 9, at: 0, sample: 0)
        queued.record(completed: all, day: 20261020, companionDays: 9, at: 0.1, sample: 0)
        let a = queued.text(at: 1, available: true, blocked: false)
        _ = queued.didRender(a!, at: 1)
        let b = queued.text(at: 4.1, available: true, blocked: false)
        check(a != nil && b == nil && queued.text(at: 7.2, available: true, blocked: false) == nil, "duplicate completion stays bounded to one and never loops")
        queued.record(completed: all, day: 20261021, companionDays: 10, at: 8, sample: 0)
        queued.record(completed: [.pet], day: 20261022, companionDays: 11, at: 9, sample: 0)
        check(queued.text(at: 9, available: true, blocked: false) == nil, "next partial day cannot deliver yesterday's pending line")
        print("PASS level feedback: progressive levels, 1/5/10 rewards, cumulative days, all-goals gate, one per day, varied wording, three seconds, busy/cancel/late/restart")
    }
}
