import Foundation
import Darwin

struct CatGrowthSnapshot: Codable, Equatable {
    var version = 4
    // Optional only to decode v1, which had no explicit reward entitlements.
    var unlockedRewards: Set<Int>? = []
    // A local once-per-day delivery receipt, not reading/activity telemetry.
    var completionShownDay: Int?
    var points: Int
    var companionDays: Int
    var completed: Set<CatGrowthGoal>
    var day: Int
    var ballSelected: Bool
    var decoration: Int?
    // v1-v3 had one slot. v4 stores independent choices; legacy slot must be nil.
    var decorations: Set<Int>? = []
    var selectedDecorations: Set<Int> {
        version < 4 ? Set(decoration.map { [$0] } ?? []) : decorations ?? []
    }
    var earnedRewards: Set<Int> {
        version == 1 ? Set(CatGrowthReward.allCases.filter { points >= $0.legacyThreshold }.map(\.rawValue)) : unlockedRewards ?? []
    }
    func validate() throws {
        guard [1, 2, 3, 4].contains(version), (0...2_000_000).contains(points),
              (0...1_000_000).contains(companionDays),
              points >= companionDays, points <= companionDays * 2,
              completed.count <= points,
              (19700101...99991231).contains(day) else { throw CatGrowthStoreError.invalid }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let c = DateComponents(year: day / 10000, month: day / 100 % 100, day: day % 100)
        guard let date = calendar.date(from: c), CatGrowth.dayKey(date, calendar: calendar) == day else { throw CatGrowthStoreError.invalid }
        if let completionShownDay {
            let c = DateComponents(year: completionShownDay / 10000, month: completionShownDay / 100 % 100, day: completionShownDay % 100)
            guard version >= 3, completionShownDay <= day, completionShownDay >= 19700101,
                  points >= 2, companionDays > 0, let date = calendar.date(from: c),
                  CatGrowth.dayKey(date, calendar: calendar) == completionShownDay,
                  completionShownDay != day || completed.count == CatGrowthGoal.allCases.count else { throw CatGrowthStoreError.invalid }
        }
        if version >= 2 {
            guard let unlockedRewards else { throw CatGrowthStoreError.invalid }
            for id in unlockedRewards {
                guard let reward = CatGrowthReward(rawValue: id), points >= reward.legacyThreshold else { throw CatGrowthStoreError.invalid }
            }
        }
        func unlocked(_ reward: CatGrowthReward) -> Bool { earnedRewards.contains(reward.rawValue) || points >= reward.threshold }
        if ballSelected && !unlocked(.sageBall) { throw CatGrowthStoreError.invalid }
        if version == 4 {
            guard decorations != nil, decoration == nil else { throw CatGrowthStoreError.invalid }
        }
        for decoration in selectedDecorations {
            guard let reward = CatGrowthReward(rawValue: decoration), reward != .sageBall,
                  unlocked(reward) else { throw CatGrowthStoreError.invalid }
        }
    }
}

enum CatGrowthStoreError: Error { case invalid, oversized }

final class CatGrowthStore {
    let url: URL
    init(url: URL) { self.url = url }
    func load() throws -> CatGrowthSnapshot? {
        let handle: FileHandle
        do { handle = try FileHandle(forReadingFrom: url) }
        catch let error as NSError {
            // fileExists also returns false for denied access: that must never
            // be treated as a fresh game that could replace existing progress.
            let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError
            guard error.domain == NSCocoaErrorDomain,
                  [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(error.code),
                  underlying == nil || (underlying?.domain == NSPOSIXErrorDomain && underlying?.code == Int(ENOENT)) else { throw error }
            return nil
        }
        defer { try? handle.close() }
        let data = try handle.read(upToCount: 65537) ?? Data()
        guard data.count <= 65536 else { throw CatGrowthStoreError.oversized }
        let snapshot = try JSONDecoder().decode(CatGrowthSnapshot.self, from: data)
        try snapshot.validate(); return snapshot
    }
    func save(_ snapshot: CatGrowthSnapshot) throws {
        try snapshot.validate()
        // Never overwrite unreadable/future-schema state, including external edits.
        _ = try load()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshot).write(to: url, options: .atomic)
    }
}
