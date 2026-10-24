import AppKit

func runMenuTests(_ app: PetApp) {
    func check(_ value: Bool, _ message: String) { if !value { fputs("FAIL: \(message)\n", stderr); exit(1) } }
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("cat-growth-production-" + UUID().uuidString)
    try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = CatGrowthStore(url: folder.appendingPathComponent("成长记录.json"))
    let prefs = UserDefaults.standard.persistentDomain(forName: "local.catcompanion.opensource") as NSDictionary?
    let text = try? Data(contentsOf: app.copyURL)
    let source = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("src")
    app.art = try! NativeCatView(resources: source)
    app.panel = PetPanel(contentRect: NSRect(x: 200, y: 100, width: 290, height: 267), styleMask: [.borderless], backing: .buffered, defer: false)
    let container = NSView(frame: NSRect(origin: .zero, size: app.panel.frame.size)); app.panel.contentView = container
    app.art.frame = container.bounds; container.addSubview(app.art)
    app.touch = PetTouchView(frame: container.bounds); app.touch.owner = app; container.addSubview(app.touch)
    app.active = true; app.motion = CatMotion(now: app.now, seed: 12)
    var date = Date()
    // Real formal-mode controller migrates legacy progress before any panel is
    // created. Already earned accessories remain usable below the new level.
    for (points, days, completed, selected) in [(7,4,"[\"pet\"]",1), (12,6,"[\"pet\",\"play\"]",2)] {
        let legacy = CatGrowthStore(url: folder.appendingPathComponent("legacy-\(points).json"))
        let key = CatGrowth.dayKey(date, calendar: .current)
        let json = "{\"version\":1,\"points\":\(points),\"companionDays\":\(days),\"completed\":\(completed),\"day\":\(key),\"ballSelected\":true,\"decoration\":\(selected)}"
        try! Data(json.utf8).write(to: legacy.url)
        let migrated = CatGrowthController(owner: app, store: legacy, currentDate: { date })
        app.growthController = migrated
        check(migrated.window == nil && migrated.storageError == nil && migrated.growth.points == points, "migration preserves XP without a panel")
        check(migrated.ballSelected && migrated.decorations == [CatGrowthReward(rawValue: selected)!] && migrated.isUnlocked(CatGrowthReward(rawValue: selected)!), "legacy selected rewards stay available below the new threshold")
        check((try! legacy.load())!.version == 4, "startup atomically persists v4 entitlements and delivery support")
        check(migrated.completionFeedback.text(at: app.now, available: true, blocked: false) == nil, "migration is silent, never retroactively celebrates")
        migrated.record(.play)
        let line = migrated.completionFeedback.text(at: app.now, available: true, blocked: false)
        check(line?.contains("第 \(days) 天") == true, "explicit interaction may deliver a legacy completed but unacknowledged day without rescoring")
        migrated.didRenderCompletion(line!, at: app.now)
        migrated.flushCompletionReceipt()
        let reopened = CatGrowthController(owner: app, store: legacy, currentDate: { date })
        reopened.record(.pet); reopened.record(.play)
        check(reopened.completionFeedback.text(at: app.now, available: true, blocked: false) == nil, "restart never repeats completion after migration")
    }
    app.art.growthBallTint = nil
    func controller() -> CatGrowthController { CatGrowthController(owner: app, store: store, currentDate: { date }) }
    var growth = controller(); app.growthController = growth
    check(growth.window == nil, "launch never auto-opens growth")
    app.pet(); app.toy.start(app.now); app.tick(); _ = app.toyKey(124)
    check(growth.growth.points == 2, "real pet and keyboard toy save first day")
    let ball = NSButton(); ball.tag = 0; growth.chooseReward(ball)
    check(app.art.growthBallTint != nil, "ball choice applies before restart")
    growth = controller(); app.growthController = growth
    check(growth.growth.points == 2 && growth.ballSelected && app.art.growthBallTint != nil, "new controller reloads progress and green ball without UI")
    app.touchBack(); app.toy.start(app.now); app.tick(); _ = app.toyKey(125)
    check(growth.growth.points == 2, "restart cannot reset today's goals")
    for _ in 0..<15 {
        date = Calendar.current.date(byAdding: .day, value: 1, to: date)!
        growth.record(.pet); growth.record(.play)
    }
    let fish = NSButton(); fish.tag = 2; growth.chooseReward(fish)
    growth = controller(); app.growthController = growth
    check(growth.growth.points == 32 && growth.decorations == [.fish] && growth.accessory.selections == [.fish], "all unlocks and selected decoration survive reopening")
    let frame = app.panel.frame
    growth.present()
    check(app.panel.frame == frame, "opening growth never moves or resizes the formal cat")
    let root = growth.window!.contentView!
    func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
    check(!descendants(root).compactMap { $0 as? NSButton }.contains { $0.title.contains("模拟") }, "formal panel has no simulation controls")
    check(!growth.responds(to: NSSelectorFromString("nextDay")), "simulation handler is absent from production")
    check(!growth.responds(to: NSSelectorFromString("selectCompanionPreview:")), "level simulation handler is absent from production")
    let diskBefore = try! Data(contentsOf: store.url)
    app.letterController = CatLetterController(text: "", stationeryURL: source.appendingPathComponent("assets/letter-stationery-v1.png"))
    app.showLetter(); app.toggleLetter(); app.showLetter(); app.letterController?.window?.performClose(nil)
    check(diskBefore == (try! Data(contentsOf: store.url)), "letter cannot write growth state")
    growth.window?.performClose(nil)
    date = Calendar.current.date(byAdding: .day, value: 12, to: date)!
    growth = controller(); app.growthController = growth; growth.refreshDay()
    check(growth.growth.points == 32 && growth.growth.completed.isEmpty && growth.decorations == [.fish], "long absence resets only daily goals")
    growth.record(.pet)
    check(growth.growth.points == 33 && !growth.growth.completed.contains(.play), "new real day continues saved progress")
    let preserved = try! Data(contentsOf: store.url)
    try! FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: folder.path)
    let denied = controller()
    try! FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)
    denied.record(.pet)
    check(denied.storageError != nil && preserved == (try! Data(contentsOf: store.url)), "startup access denial cannot reset progress after permission recovery")
    try! Data("unreadable".utf8).write(to: store.url)
    growth = controller(); app.growthController = growth; growth.record(.pet); growth.chooseReward(ball)
    check(growth.storageError != nil && (try! String(contentsOf: store.url, encoding: .utf8)) == "unreadable", "unreadable data is not replaced by a new game")
    let blocked = folder.appendingPathComponent("blocked")
    let retryStore = CatGrowthStore(url: blocked.appendingPathComponent("state.json"))
    let retry = CatGrowthController(owner: app, store: retryStore)
    try! Data().write(to: blocked)
    retry.record(.pet)
    check(retry.storageError != nil && retry.growth.points == 0, "failed save cannot pretend success or consume the daily goal")
    try! FileManager.default.removeItem(at: blocked)
    retry.record(.pet)
    check(retry.storageError == nil && retry.growth.points == 1 && (try! retryStore.load())!.points == 1, "a later input can retry after disk recovery")
    check(prefs == UserDefaults.standard.persistentDomain(forName: "local.catcompanion.opensource") as NSDictionary?, "growth never changes old preferences")
    check(text == (try? Data(contentsOf: app.copyURL)), "growth never changes copy")
    app.panel.orderOut(nil)
    print("PASS production growth: real handlers persist, reopen/cap/unlocks/selections, no simulation, unchanged cat frame, independent letter, absence, protected corrupt state, save retry")
}
