import AppKit

func runMenuTests(_ app: PetApp) {
    func check(_ result: Bool, _ message: String) { if !result { fputs("FAIL: \(message)\n", stderr); exit(1) } }
    let before = UserDefaults.standard.persistentDomain(forName: "local.catcompanion.opensource") as NSDictionary?
    let copyBefore = try? Data(contentsOf: app.copyURL)
    let formalStore = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/local.catcompanion.opensource/成长记录.json")
    let growthBefore = try? Data(contentsOf: formalStore)
    let source = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("src")
    app.art = try! NativeCatView(resources: source)
    app.panel = PetPanel(contentRect: NSRect(x: 100, y: 100, width: 290, height: 267), styleMask: [.borderless], backing: .buffered, defer: false)
    let container = NSView(frame: NSRect(origin: .zero, size: app.panel.frame.size)); app.panel.contentView = container
    app.art.frame = container.bounds; container.addSubview(app.art)
    app.touch = PetTouchView(frame: container.bounds); app.touch.owner = app; container.addSubview(app.touch)
    app.active = true; app.motion = CatMotion(now: app.now, seed: 12)
    app.copy = ["pet": ["原来的摸头短句。"]]
    let growth = CatGrowthController(owner: app); app.growthController = growth
    check(app.growthStore == nil, "preview has no path to the formal growth store")
    check(app.art.growthBallTint == nil && !growth.isUnlocked(.sageBall), "Lv0 leaves the accepted appearance untouched")
    app.pet(); let petStart = app.motion.petStart, petEnd = app.motion.petEnd
    check(growth.growth.points == 1 && growth.growth.companionDays == 1, "actual pet scores once and counts first interaction day")
    check(app.art.text == "原来的摸头短句。", "completion never overwrites the existing head phrase")
    let line = app.completionText("", at: app.now + 2)
    check(growth.window == nil && line.isEmpty, "first goal scores without opening growth, but cannot speak a daily-completion line")
    check(app.motion.petStart == petStart && app.motion.petEnd == petEnd, "completion text never changes accepted action timing")
    app.pet(); app.touchBack()
    check(growth.growth.points == 1, "head/body share one daily completion")
    check(app.completionText("", at: app.now + 5.1).isEmpty, "repeated touches cannot queue another completion")
    app.motion = CatMotion(now: app.now, seed: 12); app.toy.start(app.now); app.tick()
    func event(_ type: NSEvent.EventType, _ point: CGPoint) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: NSPoint(x: point.x, y: container.bounds.height - point.y), modifierFlags: [], timestamp: 0, windowNumber: app.panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
    }
    let p = CGPoint(x: app.art.toyFrame.position.x * 290, y: 60 + app.art.toyFrame.position.y * 290)
    let q = CGPoint(x: p.x - 20, y: p.y - 12)
    app.touch.mouseDown(with: event(.leftMouseDown, p)); app.touch.mouseDragged(with: event(.leftMouseDragged, q))
    check(growth.growth.points == 1, "held drag is not a completed task")
    app.touch.mouseUp(with: event(.leftMouseUp, q))
    check(growth.growth.points == 2 && growth.isUnlocked(.sageBall), "real drag release reaches Lv1 and unlocks only first reward")
    check(growth.window == nil && app.completionText("咦？", at: app.now).contains("第 1 天"), "released completion takes bubble priority without waiting for active ball response")
    app.art.toyFrame = app.toy.frame(app.now + 0.3)
    app.art.toyFrame = app.toy.frame(app.now + 6)
    let second = app.completionText("", at: app.now + 6)
    check(second.contains("第 1 天"), "unpainted completion remains eligible after the accepted ball response")
    growth.didRenderCompletion(second, at: app.now + 6)
    check(app.completionText("", at: app.now + 9.1).isEmpty, "all-goals line ends once")
    growth.present()
    func labels() -> [String] {
        func views(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(views) }
        return views(growth.window!.contentView!).compactMap { ($0 as? NSTextField)?.stringValue }
    }
    check(labels().contains("Lv.1") && labels().contains("Lv.5 解锁") && labels().contains("Lv.10 解锁"), "actual panel uses level-only heading and level-gated reward labels")
    let ball = NSButton(); ball.tag = 0; growth.chooseReward(ball)
    check(growth.ballSelected && app.art.growthBallTint != nil, "unlocked preview ball remains usable")
    for _ in 0..<4 { growth.nextDay(); growth.record(.pet); growth.record(.play) }
    check(growth.growth.points == 10 && !growth.isUnlocked(.flower), "five full days cannot bypass Lv5")
    growth.nextDay(); growth.record(.pet); growth.record(.play)
    check(growth.isUnlocked(.flower), "six full interaction days unlock the flower")
    let flower = NSButton(); flower.tag = 1; growth.chooseReward(flower)
    check(growth.decorations == [.flower], "level-unlocked decoration can be selected")
    for _ in 0..<9 { growth.nextDay(); growth.record(.pet); growth.record(.play) }
    check(!growth.isUnlocked(.fish), "fifteen full days cannot bypass Lv10")
    growth.nextDay(); app.touchBack()
    check(!growth.isUnlocked(.fish), "first goal of sixteenth day is still below Lv10")
    growth.record(.play)
    check(growth.isUnlocked(.fish) && growth.growth.companionDays == 16, "sixteenth full interaction day reaches Lv10")
    app.paused = true; check(app.completionText("休息", at: app.now + 2) == "休息", "rest preserves its own text and cancels completion")
    app.paused = false; check(app.completionText("", at: app.now + 3).isEmpty, "resume has no catch-up completion")
    growth.nextDay(); app.touchBack(); growth.record(.play); app.petVisible = false
    check(app.completionText("", at: app.now + 2).isEmpty, "hidden cat clears feedback")
    app.petVisible = true; check(app.completionText("", at: app.now + 3).isEmpty, "show does not replay")
    growth.nextDay(); app.pet(); growth.record(.play)
    let days = growth.growth.companionDays, points = growth.growth.points
    app.letterController = CatLetterController(text: "", stationeryURL: source.appendingPathComponent("assets/letter-stationery-v1.png"))
    app.showLetter(); app.letterController?.window?.performClose(nil)
    check(app.completionText("", at: app.now + 3).isEmpty && growth.growth.companionDays == days && growth.growth.points == points, "letter is independent and cannot replay pending feedback on close")
    app.settingsReady = true; app.saveSettings(); try! app.ensureCopy()
    check(before == UserDefaults.standard.persistentDomain(forName: "local.catcompanion.opensource") as NSDictionary?, "preview does not write formal settings")
    check(copyBefore == (try? Data(contentsOf: app.copyURL)) && growthBefore == (try? Data(contentsOf: formalStore)), "preview leaves formal copy and existing growth bytes unchanged")
    growth.window?.performClose(nil); app.panel.orderOut(nil)
    print("PASS level real handlers: no panel required, both goals before speech, release priority, original action clocks, 1/6/16-day rewards, cancellation, letter isolation, no formal writes")
}
