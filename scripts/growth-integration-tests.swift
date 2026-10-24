import AppKit

// Compile with CAT_MENU_TEST to exercise real PetApp handlers, not a second app.
func runMenuTests(_ app: PetApp) {
    func check(_ result: Bool, _ message: String) {
        if !result { fputs("FAIL: \(message)\n", stderr); exit(1) }
    }
    let before = UserDefaults.standard.persistentDomain(forName: "local.catcompanion.opensource") as NSDictionary?
    let copyBefore = try? Data(contentsOf: app.copyURL)
    let source = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("src")
    app.art = try! NativeCatView(resources: source)
    app.panel = PetPanel(contentRect: NSRect(x: 150, y: 150, width: 290, height: 60 + 290 * 1085 / 1525), styleMask: [.borderless], backing: .buffered, defer: false)
    let container = NSView(frame: NSRect(origin: .zero, size: app.panel.frame.size))
    app.panel.contentView = container; app.art.frame = container.bounds; container.addSubview(app.art)
    app.touch = PetTouchView(frame: container.bounds); app.touch.owner = app; container.addSubview(app.touch)
    app.active = true; app.petVisible = true; app.paused = false
    app.motion = CatMotion(now: app.now, seed: 12)
    var testDate = Date()
    let growth = CatGrowthController(owner: app, currentDate: { testDate }); app.growthController = growth
    growth.accessory.frame = container.bounds
    container.addSubview(growth.accessory, positioned: .above, relativeTo: app.art)
    func capture(_ view: NSView, _ name: String) {
        guard let path = ProcessInfo.processInfo.environment["CAT_GROWTH_EVIDENCE"] else { return }
        let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
        view.cacheDisplay(in: view.bounds, to: rep)
        try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path).appendingPathComponent(name + ".png"))
    }
    func event(_ type: NSEvent.EventType, _ point: CGPoint) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: NSPoint(x: point.x, y: container.bounds.height - point.y), modifierFlags: [], timestamp: 0, windowNumber: app.panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
    }
    func click(_ point: CGPoint) {
        app.touch.mouseDown(with: event(.leftMouseDown, point)); app.touch.mouseUp(with: event(.leftMouseUp, point))
    }
    func toyStart() {
        app.active = true; app.paused = false
        app.motion = CatMotion(now: app.now, seed: 12); app.toy.start(app.now); app.tick()
    }
    func ballPoint() -> CGPoint { CGPoint(x: app.art.toyFrame.position.x * 290, y: 60 + app.art.toyFrame.position.y * 290) }
    func beginAndMove() -> CGPoint {
        toyStart(); let p = ballPoint()
        app.touch.mouseDown(with: event(.leftMouseDown, p))
        let q = CGPoint(x: p.x + 18, y: p.y - 20)
        app.touch.mouseDragged(with: event(.leftMouseDragged, q)); return q
    }
    check(app.makeMenu().items.contains { $0.title == "成长小窝" }, "growth is available only by explicit menu choice")
    click(CGPoint(x: 145, y: 222)); check(growth.growth.points == 0, "bed click is not a pet")
    click(CGPoint(x: 170, y: 112)); check(growth.growth.points == 1, "real head click credits pet")
    click(CGPoint(x: 80, y: 140)); check(growth.growth.points == 1, "back click shares the daily cap")
    toyStart(); click(ballPoint()); check(growth.growth.points == 1, "take out and tap are not play")
    var q = beginAndMove()
    check(growth.growth.points == 1, "drag is not credited until mouse up")
    app.art.toyFrame = app.toy.frame(app.now, reduced: true, canBat: false)
    app.touch.mouseUp(with: event(.leftMouseUp, q))
    check(growth.growth.points == 2, "real drag and release credits play even without a reduced-motion cat bat")
    growth.nextDay(); q = beginAndMove(); app.touch.cancelContact(); app.touch.mouseUp(with: event(.leftMouseUp, q))
    check(growth.growth.points == 2, "cancelled drag cannot count")
    q = beginAndMove(); app.togglePause(); app.touch.mouseUp(with: event(.leftMouseUp, q))
    check(growth.growth.points == 2, "pause cancels unfinished goal")
    app.paused = false; app.active = true
    app.touchBack(); check(growth.growth.points == 3, "next day body contact credits pet")
    toyStart(); check(app.toyKey(124), "keyboard ball move is handled")
    check(growth.growth.points == 4, "keyboard play is equally eligible")
    _ = app.toyKey(124); check(growth.growth.points == 4, "keyboard cannot farm points")
    growth.nextDay(); app.paused = true; app.pet(); app.touchBack()
    check(growth.growth.points == 4, "resting does not score phantom contacts")
    app.paused = false; app.active = false; app.pet(); app.touchBack()
    check(growth.growth.points == 4, "hidden cat cannot score contacts")
    growth.present(); let window = growth.window!
    app.letterController = CatLetterController(text: "", stationeryURL: source.appendingPathComponent("assets/letter-stationery-v1.png"))
    app.showLetter(); app.toggleLetter(); app.showLetter(); app.letterController?.window?.performClose(nil)
    check(growth.growth.points == 4 && growth.growth.completed.isEmpty, "letter opening, closing and rereading are wholly independent")
    window.performClose(nil)
    app.active = true; app.pet()
    check(window.isVisible == false && growth.growth.points == 5, "closed growth panel never reopens on progress")
    toyStart(); _ = app.toyKey(123)
    check(window.isVisible == false && growth.growth.points == 6, "reward unlocking is silent")
    growth.present(); check(growth.window === window && growth.growth.points == 6, "close and reopen retains this session")
    window.cancelOperation(nil); check(!window.isVisible, "Escape closes growth panel")
    growth.present()
    let closeKey = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "w", charactersIgnoringModifiers: "w", isARepeat: false, keyCode: 13)!
    check(window.performKeyEquivalent(with: closeKey) && !window.isVisible, "Cmd-W closes growth panel")
    growth.present()
    let ball = NSButton(); ball.tag = 0; growth.chooseReward(ball)
    check(app.art.growthBallTint != nil && growth.ballSelected, "unlocked ball reward is usable")
    growth.chooseReward(ball); check(app.art.growthBallTint == nil, "ball color is reversible")
    app.toy.finish(app.now, immediate: true); app.art.toyFrame = CatToyFrame(); app.art.update(CatPose())
    for _ in 0..<3 { growth.nextDay(); growth.record(.pet); growth.record(.play) }
    let flower = NSButton(); flower.tag = 1; growth.chooseReward(flower)
    check(growth.accessory.selections == [.flower] && growth.accessory.hitTest(.zero) == nil, "decoration never steals touches")
    capture(container, "flower-290pt")
    let fish = NSButton(); fish.tag = 2; growth.chooseReward(fish)
    check(growth.accessory.selections == [.flower], "locked rewards cannot be selected")
    for _ in 0..<10 { growth.nextDay(); app.active = true; app.pet(); toyStart(); _ = app.toyKey(124) }
    growth.chooseReward(fish); check(growth.accessory.selections == [.flower,.fish], "later reward keeps the already selected flower")
    app.toy.finish(app.now, immediate: true); app.art.toyFrame = CatToyFrame(); app.art.update(CatPose())
    capture(container, "fish-290pt"); capture(window.contentView!, "growth-panel")
    growth.chooseReward(fish); check(growth.accessory.selections == [.flower], "fish can be removed without hiding flower")
    for code: UInt16 in [123, 124, 125, 126, 49, 36] {
        growth.nextDay(); toyStart()
        let points = growth.growth.points
        _ = app.toyKey(code)
        check(growth.growth.points == points + 1, "all six keyboard commands count, including vertical nudges")
        _ = app.toyKey(code); check(growth.growth.points == points + 1, "keyboard goal remains capped")
    }
    let points = growth.growth.points
    check(!growth.growth.completed.isEmpty, "yesterday has a completed goal before the calendar transition")
    testDate = Calendar.current.date(byAdding: .day, value: 1, to: testDate)!
    NotificationCenter.default.post(name: .NSCalendarDayChanged, object: nil)
    check(growth.growth.points == points && growth.growth.completed.isEmpty, "open panel updates at calendar rollover without changing cumulative growth")
    app.settingsReady = true; app.saveSettings(); try! app.ensureCopy()
    check(before == UserDefaults.standard.persistentDomain(forName: "local.catcompanion.opensource") as NSDictionary?, "preview cannot modify formal settings")
    check(copyBefore == (try? Data(contentsOf: app.copyURL)), "preview never overwrites user copy")
    window.performClose(nil); app.panel.orderOut(nil)
    print("PASS growth real handlers: head/body, mouse drag, keyboard, cap, cancel, pause/hidden, independent letter, quiet unlock, reusable rewards and no formal writes")
}
