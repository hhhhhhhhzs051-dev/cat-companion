import AppKit

// Exercise the actual formal controller with synthetic disk state. Display only
// the level, with no relationship titles or mutation of saved progress,
// speech, choices or pet geometry.
func runMenuTests(_ app: PetApp) {
    func check(_ condition: Bool, _ message: String) {
        if !condition { fputs("FAIL: \(message)\n", stderr); exit(1) }
    }
    func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("cat-companion-test-" + UUID().uuidString)
    try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let prefs = UserDefaults.standard.persistentDomain(forName: "local.catcompanion.opensource") as NSDictionary?
    let source = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("src")
    app.art = try! NativeCatView(resources: source)
    app.panel = PetPanel(contentRect: NSRect(x: 100, y: 100, width: 290, height: 267),
                         styleMask: [.borderless], backing: .buffered, defer: false)
    let container = NSView(frame: app.panel.contentRect(forFrameRect: app.panel.frame))
    app.panel.contentView = container; app.art.frame = container.bounds; container.addSubview(app.art)
    app.active = true; app.motion = CatMotion(now: app.now, seed: 7)
    let date = Date(), day = CatGrowth.dayKey(date, calendar: .current)
    let cases: [(Int, Int, Int?, Int)] = [
        (6, 3, nil, 30), (12, 5, nil, 30), (19, 7, nil, 30),
        (32, 10, nil, 30), (97, 20, nil, 30),
        (195, 30, 30, 40), (284, 37, 30, 40),
        (492, 50, 50, 60), (1817, 100, 100, 110)
    ]
    for (points, level, last, next) in cases {
        let store = CatGrowthStore(url: folder.appendingPathComponent("\(level).json"))
        // Lv5 fixture keeps the legacy all-reward entitlement: it must not
        // falsely jump to the level associated with three unlocked objects.
        let rewards: Set<Int> = points >= 32 || level == 5 ? [0, 1, 2] : [0]
        let saved = CatGrowthSnapshot(unlockedRewards: rewards, completionShownDay: day,
            points: points, companionDays: (points + 1) / 2, completed: [.pet, .play],
            day: day, ballSelected: true, decoration: nil,
            decorations: points >= 32 ? [1, 2] : [])
        try! store.save(saved)
        let before = try! Data(contentsOf: store.url), frame = app.panel.frame, pose = app.art.pose
        let controller = CatGrowthController(owner: app, store: store, currentDate: { date })
        app.growthController = controller
        check(controller.window == nil, "loading must not automatically open growth")
        controller.present()
        let views = descendants(controller.window!.contentView!)
        let texts = views.compactMap { ($0 as? NSTextField)?.stringValue }
        check(texts.contains("Lv.\(level)"), "level heading must contain only Lv and its number, without a stage title")
        let removedTitles = ["初次相伴", "渐渐熟悉", "熟悉的陪伴", "放心靠近", "安心相伴", "自在相伴", "默契相伴", "老朋友", "日常有你"]
        check(!texts.contains { text in removedTitles.contains { text.contains($0) } }, "no relationship title remains anywhere in the panel")
        for label in views.compactMap({ $0 as? NSTextField }) {
            let width = (label.stringValue as NSString).size(withAttributes: [.font: label.font!]).width
            check(width <= label.bounds.width + 1, "growth labels remain readable without horizontal clipping: \(label.stringValue)")
        }
        let scroll = views.compactMap { $0 as? NSScrollView }.first!
        check(scroll.documentView!.bounds.height >= scroll.contentSize.height, "small screens retain scroll access to all sections")
        let originalScrollFrame = scroll.frame
        let footer = views.compactMap { $0 as? NSTextField }.first { $0.stringValue.hasPrefix("成长和小物保存在") }!
        let levelHeading = views.compactMap { $0 as? NSTextField }.first { $0.stringValue == "Lv.\(level)" }!
        scroll.setFrameSize(NSSize(width: originalScrollFrame.width, height: 280))
        _ = scroll.documentView!.scrollToVisible(footer.frame)
        scroll.reflectScrolledClipView(scroll.contentView)
        check(scroll.documentVisibleRect.contains(footer.frame), "constrained viewport can scroll to the final save note")
        _ = scroll.documentView!.scrollToVisible(levelHeading.frame)
        scroll.reflectScrolledClipView(scroll.contentView)
        check(scroll.documentVisibleRect.contains(levelHeading.frame), "constrained viewport can return to level and experience")
        scroll.frame = originalScrollFrame
        check(texts.contains { $0.contains("Lv.3") && $0.contains("短句") }, "Lv3 earned speech is visible")
        check(texts.contains { $0.contains("Lv.7") && $0.contains("短句") } == (level >= 7), "Lv7 speech is shown only after earning it")
        check(texts.contains("下一个陪伴纪念：Lv.\(next)"), "next long-term milestone remains meaningful beyond 30")
        if let last { check(texts.contains { $0.hasPrefix("Lv.\(last) ·") }, "show the reached milestone, not a future reward") }
        check(views.compactMap { $0 as? NSButton }.filter { $0.action == NSSelectorFromString("chooseReward:") }.count == 3,
              "milestones must not invent extra rewards or claim buttons")
        check(!controller.responds(to: NSSelectorFromString("selectCompanionPreview:")), "formal app cannot expose preview level mutation")
        controller.window?.performClose(nil); controller.present(); controller.refreshDay()
        check(before == (try! Data(contentsOf: store.url)), "reading/reopening milestones never changes the save or receipts")
        check(app.panel.frame == frame && app.art.pose == pose, "reading growth leaves pet pose and geometry untouched")
        check(controller.decorations == Set((saved.decorations ?? []).compactMap(CatGrowthReward.init(rawValue:))), "display preserves independent accessory choices")
        check(controller.completionFeedback.text(at: app.now, available: true, blocked: false) == nil, "milestones never enqueue speech")
        controller.window?.performClose(nil)
    }
    check(prefs == UserDefaults.standard.persistentDomain(forName: "local.catcompanion.opensource") as NSDictionary?, "isolated tests preserve real preferences")
    print("PASS real growth panel: level-only headings, no relationship titles, earned familiarity, long-term milestones, no new rewards/speech/writes, unchanged pet geometry and selections")
}
