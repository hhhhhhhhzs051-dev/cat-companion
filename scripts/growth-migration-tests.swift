import Foundation

@main struct GrowthMigrationTests {
    static func main() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 12))!
        var fresh = CatGrowth(date: date, calendar: calendar)
        for offset in 0..<3 {
            let day = calendar.date(byAdding: .day, value: offset, to: date)!
            fresh.record(.pet, at: day); fresh.record(.play, at: day)
        }
        precondition(fresh.points == 6 && !fresh.unlocked(.flower), "new progress must use Lv.5, not the old six-point unlock")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("cat-level-migration-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = CatGrowthStore(url: folder.appendingPathComponent("growth.json"))
        for points in [0, 1, 2, 5, 6, 11, 12, 32] {
            for selected in [false, true] where !selected || points >= 12 {
                let json = "{\"version\":1,\"points\":\(points),\"companionDays\":\((points+1)/2),\"completed\":[],\"day\":20261018,\"ballSelected\":\(selected),\"decoration\":\(selected ? "2" : "null")}"
                try Data(json.utf8).write(to: store.url)
                let saved = try store.load()!
                let migrated = CatGrowth(snapshot: saved, calendar: calendar)
                for reward in CatGrowthReward.allCases {
                    precondition(migrated.unlocked(reward) == (points >= [2,6,12][reward.rawValue]), "all earned rewards survive, including unselected ones")
                }
                let next = migrated.snapshot(ballSelected: saved.ballSelected, decoration: saved.decoration.flatMap(CatGrowthReward.init(rawValue:)))
                precondition(next.version == 4 && next.points == points && next.companionDays == saved.companionDays && next.completed == saved.completed && next.day == saved.day)
                try store.save(next)
                let reopened = CatGrowth(snapshot: try store.load()!, calendar: calendar)
                for reward in CatGrowthReward.allCases { precondition(reopened.unlocked(reward) == migrated.unlocked(reward)) }
                let reloaded = try store.load()!
                precondition(reloaded == next, "selection and entitlement round trip")
            }
        }
        let freshSnapshot = fresh.snapshot(ballSelected: false, decoration: nil)
        try store.save(freshSnapshot)
        let freshReloaded = CatGrowth(snapshot: try store.load()!)
        precondition(!freshReloaded.unlocked(.flower), "new v2 progress is never interpreted as a legacy unlock")
        print("PASS migration: new curve, v1 earned rewards including unselected, v2 restart, exact progress and selection")
    }
}
