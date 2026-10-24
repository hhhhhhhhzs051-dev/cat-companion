import AppKit

func runMenuTests(_ app: PetApp) {
    func check(_ ok: Bool, _ message: String) { if !ok { fputs("FAIL: \(message)\n", stderr); exit(1) } }
    if let index = CommandLine.arguments.firstIndex(of: "--read-pair") {
        let saved = try! CatGrowthStore(url: URL(fileURLWithPath: CommandLine.arguments[index + 1])).load()!
        check(saved.version == 4 && saved.selectedDecorations == [1,2] && saved.points == 32 && saved.ballSelected,
              "independent process restores both switches and progress")
        print("PASS independent process restored both accessory switches"); return
    }
    let prefs = UserDefaults.standard.persistentDomain(forName: "local.catcompanion.opensource") as NSDictionary?
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("cat-pair-persistence-" + UUID().uuidString)
    try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = CatGrowthStore(url: folder.appendingPathComponent("state.json"))
    app.art = try! NativeCatView(resources: URL(fileURLWithPath: "src"))
    let day = CatGrowth.dayKey(Date(), calendar: .current)
    let legacy = CatGrowthSnapshot(version: 3, unlockedRewards: [0,1,2], completionShownDay: day,
        points: 32, companionDays: 16, completed: [.pet,.play], day: day, ballSelected: true, decoration: nil)
    try! store.save(legacy)
    var date = Date()
    func reopen(_ storage: CatGrowthStore = store) -> CatGrowthController {
        CatGrowthController(owner: app, store: storage, currentDate: { date })
    }
    var growth = reopen()
    let flower = NSButton(), fish = NSButton(); flower.tag = 1; fish.tag = 2
    growth.chooseReward(flower); growth.chooseReward(fish)
    let json = try! JSONSerialization.jsonObject(with: Data(contentsOf: store.url)) as! [String:Any]
    check(Set(json["decorations"] as? [Int] ?? []) == [1,2], "both independently enabled decorations must persist together")
    let child = Process(); child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
    child.arguments = ["--read-pair", store.url.path]; try! child.run(); child.waitUntilExit()
    check(child.terminationStatus == 0, "independent restart succeeded")
    for (button, expected) in [(flower,Set([CatGrowthReward.fish])), (fish,Set<CatGrowthReward>()), (flower,Set([.flower])), (fish,Set([.flower,.fish]))] {
        growth.chooseReward(button); growth = reopen()
        check(growth.decorations == expected && growth.accessory.selections == expected, "each of four switch combinations survives reopening")
        let saved = try! store.load()!
        check(saved.points == 32 && saved.companionDays == 16 && saved.completed == [.pet,.play] && saved.ballSelected && saved.completionShownDay == day,
              "toggles preserve growth, green ball and once-per-day completion receipt")
    }
    growth.record(.pet); growth.record(.play)
    check(growth.completionFeedback.text(at: app.now, available: true, blocked: false) == nil, "migration and restart never repeat a delivered completion line")
    let retained = try! Data(contentsOf: store.url)
    try! FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: folder.path)
    growth.chooseReward(flower)
    try! FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)
    check(growth.storageError != nil && growth.decorations == [.flower,.fish] && growth.accessory.selections == [.flower,.fish], "failed save leaves UI and both selections unchanged")
    check(retained == (try! Data(contentsOf: store.url)), "failed atomic save retains original bytes")
    growth.chooseReward(flower); check(growth.storageError == nil && reopen().decorations == [.fish], "explicit retry succeeds after disk recovery")
    growth.chooseReward(flower)
    date = Calendar.current.date(byAdding: .day, value: 1, to: date)!
    growth.refreshDay(); growth = reopen()
    check(growth.decorations == [.flower,.fish] && growth.growth.points == 32 && growth.growth.completed.isEmpty, "day rollover keeps both choices without scoring")
    // Migrate every prior supported schema and selected/empty slot. Legacy
    // entitlements may be below today's level threshold and must remain usable.
    for version in [1,2,3] { for choice in [nil,1,2] as [Int?] {
        let migrationStore = CatGrowthStore(url: folder.appendingPathComponent("v\(version)-\(choice ?? -1).json"))
        let old = CatGrowthSnapshot(version: version, unlockedRewards: version == 1 ? nil : [0,1,2],
            completionShownDay: version == 3 ? day : nil, points: 12, companionDays: 6,
            completed: [.pet,.play], day: day, ballSelected: true, decoration: choice)
        try! migrationStore.save(old)
        let migrated = reopen(migrationStore), saved = try! migrationStore.load()!
        check(saved.version == 4 && saved.decoration == nil && saved.selectedDecorations == Set(choice.map { [$0] } ?? []), "single-slot migration retains exact selected state without enabling the other item")
        check(saved.points == old.points && saved.companionDays == old.companionDays && saved.completed == old.completed && saved.day == old.day && saved.completionShownDay == old.completionShownDay && saved.ballSelected == old.ballSelected && saved.earnedRewards == old.earnedRewards,
              "migration preserves all progress, earned rights and delivery receipt")
        check(migrated.isUnlocked(.fish) && migrated.storageError == nil && migrated.window == nil, "legacy rights stay available without opening UI")
    }}
    let lockedStore = CatGrowthStore(url: folder.appendingPathComponent("locked.json"))
    let low = CatGrowthSnapshot(version:3,unlockedRewards:[0],points:6,companionDays:3,completed:[],day:day,ballSelected:false,decoration:nil)
    try! lockedStore.save(low)
    let locked = reopen(lockedStore); locked.chooseReward(flower); locked.chooseReward(fish)
    check(locked.decorations.isEmpty && !locked.isUnlocked(.flower) && !locked.isUnlocked(.fish) && locked.growth.points == 6, "real-like v3 state receives no demo rewards or selections")
    let migrationFailure = CatGrowthStore(url: folder.appendingPathComponent("migration-failure.json"))
    try! migrationFailure.save(legacy)
    let oldBytes = try! Data(contentsOf: migrationFailure.url)
    try! FileManager.default.setAttributes([.posixPermissions:0o500],ofItemAtPath:folder.path)
    let failed = reopen(migrationFailure)
    try! FileManager.default.setAttributes([.posixPermissions:0o700],ofItemAtPath:folder.path)
    failed.chooseReward(flower); failed.record(.pet)
    check(failed.storageError != nil && oldBytes == (try! Data(contentsOf:migrationFailure.url)), "failed migration cannot overwrite or falsely continue saving")
    // Strict v4 validation rejects absent, invalid, locked or ambiguous choices.
    let good = try! store.load()!
    for mutate in [
        { (s:inout CatGrowthSnapshot) in s.decorations = nil },
        { (s:inout CatGrowthSnapshot) in s.decorations = [0] },
        { (s:inout CatGrowthSnapshot) in s.decorations = [99] },
        { (s:inout CatGrowthSnapshot) in s.decoration = 1 },
        { (s:inout CatGrowthSnapshot) in s.points = 2; s.companionDays = 1; s.unlockedRewards = [0]; s.completionShownDay = nil },
        { (s:inout CatGrowthSnapshot) in s.version = 99 }
    ] {
        var bad = good; mutate(&bad)
        do {try bad.validate(); check(false,"invalid v4 must fail validation")} catch {}
    }
    let corrupt = Data("{\"version\":99}".utf8); try! corrupt.write(to:store.url)
    growth = reopen(); growth.chooseReward(flower); growth.record(.pet)
    check(growth.storageError != nil && corrupt == (try! Data(contentsOf:store.url)), "unknown file is never overwritten")
    check(prefs == UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?, "isolated persistence tests do not change formal preferences")
    print("PASS accessory persistence: four combinations/restart, v1-v3 migration, legacy rewards, receipt, rollover, locked state, failed save/migration, retry and invalid/future schema")
}
