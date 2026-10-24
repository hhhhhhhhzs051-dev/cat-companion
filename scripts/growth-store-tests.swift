import Foundation

@main struct GrowthStoreTests {
    static func main() throws {
        if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--read" {
            let saved = try CatGrowthStore(url: URL(fileURLWithPath: CommandLine.arguments[2])).load()!
            precondition(saved.points == 32 && saved.companionDays == 16 && saved.completed == [.pet, .play] && saved.ballSelected && saved.decoration == 2)
            print("PASS independent process restored saved growth and rewards"); return
        }
        func check(_ value: Bool, _ message: String = "persistence assertion") { precondition(value, message) }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("cat-growth-store-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("成长记录.json")
        let store = CatGrowthStore(url: url)
        check(try store.load() == nil, "a first install has no fake progress")
        let saved = CatGrowthSnapshot(version: 3, points: 32, companionDays: 16, completed: [.pet, .play], day: 20261016, ballSelected: true, decoration: 2)
        try store.save(saved)
        let reopened = try CatGrowthStore(url: url).load()
        precondition(reopened == saved, "restart must preserve points, daily completion, unlocked rewards and selection")
        let process = Process(); process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0]); process.arguments = ["--read", url.path]
        try process.run(); process.waitUntilExit(); precondition(process.terminationStatus == 0)
        try store.save(saved)
        check(try store.load() == saved, "saving again is idempotent")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: folder.path)
        var deniedWasError = false
        do { _ = try store.load() } catch { deniedWasError = true }
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)
        precondition(deniedWasError, "inaccessible existing progress must never become an empty new game")
        check(try store.load() == saved, "restored access retains all existing rewards")
        let future = "{\"version\":99}"
        try Data(future.utf8).write(to: url)
        do { _ = try store.load(); preconditionFailure("future schema must not silently reset") } catch {}
        check(try String(contentsOf: url, encoding: .utf8) == future)
        try Data("broken json".utf8).write(to: url)
        do { _ = try store.load(); preconditionFailure("corrupt state must not silently reset") } catch {}
        check(try String(contentsOf: url, encoding: .utf8) == "broken json")
        try Data(repeating: 32, count: 65537).write(to: url)
        do { _ = try store.load(); preconditionFailure("oversized state must be bounded") } catch {}
        var invalid = saved
        for mutate in [
            { (s: inout CatGrowthSnapshot) in s.points = -1 },
            { (s: inout CatGrowthSnapshot) in s.companionDays = 0 },
            { (s: inout CatGrowthSnapshot) in s.day = 20260230 },
            { (s: inout CatGrowthSnapshot) in s.decoration = 99 },
            { (s: inout CatGrowthSnapshot) in s.points = 2; s.companionDays = 1 },
            { (s: inout CatGrowthSnapshot) in s.points = Int.max },
            { (s: inout CatGrowthSnapshot) in s.unlockedRewards = nil },
            { (s: inout CatGrowthSnapshot) in s.unlockedRewards = [99] },
            { (s: inout CatGrowthSnapshot) in s.points = 2; s.companionDays = 1; s.decoration = nil; s.unlockedRewards = [2] }
        ] {
            invalid = saved; mutate(&invalid)
            try JSONEncoder().encode(invalid).write(to: url)
            do { _ = try store.load(); preconditionFailure("invalid/unearned state must be rejected") } catch {}
        }
        let blocker = folder.appendingPathComponent("not-a-directory")
        try Data().write(to: blocker)
        do { try CatGrowthStore(url: blocker.appendingPathComponent("state.json")).save(saved); preconditionFailure("disk failure must be surfaced") } catch {}
        print("PASS growth persistence: restart, daily cap state, reward selection, idempotence, bounded invalid/future state, disk failure")
    }
}
