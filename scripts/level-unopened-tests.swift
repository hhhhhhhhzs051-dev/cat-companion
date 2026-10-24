import AppKit

func runMenuTests(_ app: PetApp) {
    func check(_ value: Bool, _ message: String) { if !value { fputs("FAIL: \(message)\n", stderr); exit(1) } }
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("cat-level-unopened-" + UUID().uuidString)
    try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let source = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("src")
    app.art = try! NativeCatView(resources: source)
    app.panel = PetPanel(contentRect: NSRect(x: 0, y: 0, width: 290, height: 267), styleMask: [.borderless], backing: .buffered, defer: false)
    let container = NSView(frame: NSRect(origin: .zero, size: app.panel.frame.size)); app.panel.contentView = container
    app.art.frame = container.bounds; container.addSubview(app.art)
    app.touch = PetTouchView(frame: container.bounds); app.touch.owner = app; container.addSubview(app.touch)
    app.active = true; app.copy = ["pet": ["原来的摸头短句。"]]
    func input(_ goal: CatGrowthGoal) {
        app.motion = CatMotion(now: app.now, seed: 12)
        if goal == .pet { app.pet() }
        else { app.toy.start(app.now); app.tick(); _ = app.toyKey(124) }
    }
    for first in CatGrowthGoal.allCases {
        let second: CatGrowthGoal = first == .pet ? .play : .pet
        for reloadMidway in [false, true] {
            var date = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 12))!
            let store = CatGrowthStore(url: folder.appendingPathComponent("\(first.rawValue)-\(reloadMidway).json"))
            func make() -> CatGrowthController { CatGrowthController(owner: app, store: store, currentDate: { date }) }
            var growth = make(); app.growthController = growth
            input(first)
            check(growth.window == nil && growth.growth.points == 1 && growth.growth.companionDays == 1, "first goal scores with no growth window ever created")
            check(growth.completionFeedback.text(at: app.now + 2, available: true, blocked: false) == nil, "first goal alone has no queued daily line in either order")
            if reloadMidway {
                growth = make(); app.growthController = growth
                check(growth.window == nil && growth.growth.points == 1 && growth.growth.completed == [first], "partial state is restored without opening growth")
            }
            input(second)
            check(growth.window == nil && growth.growth.points == 2 && growth.growth.completed.count == 2, "second goal commits the full day independently of panel")
            let t = app.now
            check(growth.completionFeedback.text(at: t, available: true, blocked: false)?.contains("第 1 天") == true, "full committed state queues one day-count line, including partial restart")
            growth.didRenderCompletion(growth.completionFeedback.text(at: t, available: true, blocked: false)!, at: t)
            growth.flushCompletionReceipt()
            check(growth.completionFeedback.text(at: t + 3.1, available: true, blocked: false) == nil, "one line ends")
            let saved = try! Data(contentsOf: store.url)
            input(first); input(second)
            check(growth.growth.points == 2 && saved == (try! Data(contentsOf: store.url)), "repeat input neither rescores nor rewrites state")
            check(growth.completionFeedback.text(at: t + 4, available: true, blocked: false) == nil, "repeat input cannot queue another daily line")
            growth = make(); app.growthController = growth
            input(first); input(second)
            check(growth.window == nil && growth.growth.points == 2 && growth.completionFeedback.text(at: app.now + 6, available: true, blocked: false) == nil, "fully completed day never replays on reload or later interaction")
            date = Calendar.current.date(byAdding: .day, value: 3, to: date)!
            input(.pet)
            check(growth.window == nil && growth.growth.points == 3 && growth.growth.completed == [.pet] && growth.growth.companionDays == 2, "date refresh and cumulative interaction days do not depend on panel")
            check(growth.completionFeedback.text(at: app.now, available: true, blocked: false) == nil, "next partial day is silent")
            input(.play)
            check(growth.completionFeedback.text(at: app.now, available: true, blocked: false)?.contains("第 2 天") == true, "next fully completed interaction day speaks its cumulative day")
            let latest = try! store.load()!
            check(latest.points == 4 && latest.companionDays == 2 && growth.window == nil, "new day saved without a window")
        }
    }
    // A failed commit of the second task must not pretend the day was completed.
    let store = CatGrowthStore(url: folder.appendingPathComponent("failure.json"))
    let growth = CatGrowthController(owner: app, store: store); app.growthController = growth
    input(.pet)
    let valid = try! Data(contentsOf: store.url)
    try! Data("invalid".utf8).write(to: store.url)
    input(.play)
    check(growth.growth.points == 1 && growth.storageError != nil && growth.completionFeedback.text(at: app.now + 6, available: true, blocked: false) == nil, "failed second-goal save cannot speak or consume completion")
    try! valid.write(to: store.url)
    input(.play)
    check(growth.growth.points == 2 && growth.completionFeedback.text(at: app.now + 6, available: true, blocked: false) != nil, "a later successful save can complete the day once")
    app.panel.orderOut(nil)
    print("PASS unopened growth: both goal orders, partial/full reload, one daily line, no panel, no duplicate score, skipped dates, failed second-save retry")
}
