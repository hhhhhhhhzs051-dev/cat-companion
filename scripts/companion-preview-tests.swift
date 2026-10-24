import AppKit

func runMenuTests(_ app: PetApp) {
    func check(_ condition: Bool, _ message: String) {
        if !condition { fputs("FAIL: \(message)\n", stderr); exit(1) }
    }
    func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
    let prefs = UserDefaults.standard.persistentDomain(forName: "local.catcompanion.opensource") as NSDictionary?
    check(app.isPlayPreview && app.growthStore == nil, "preview cannot acquire real growth storage")
    app.art = try! NativeCatView(resources: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("src"))
    app.panel = PetPanel(contentRect: NSRect(x: 100, y: 100, width: 290, height: 267),
                         styleMask: [.borderless], backing: .buffered, defer: false)
    let body = NSView(frame: NSRect(origin: .zero, size: app.panel.frame.size))
    app.panel.contentView = body; app.art.frame = body.bounds; body.addSubview(app.art)
    app.active = true
    let controller = CatGrowthController(owner: app)
    app.growthController = controller; controller.present()
    let picker = descendants(controller.window!.contentView!).compactMap { $0 as? NSPopUpButton }.first!
    let frame = app.panel.frame, pose = app.art.pose
    let choices = [(0,0),(6,3),(32,10),(195,30),(284,37),(492,50),(1817,100),(2182,110),(6,3),(0,0)]
    for (points, level) in choices {
        check(picker.selectItem(withTag: points), "requested simulated level is available")
        controller.selectCompanionPreview(picker)
        let texts = descendants(controller.window!.contentView!).compactMap { ($0 as? NSTextField)?.stringValue }
        check(controller.growth.points == points && texts.contains("Lv.\(level)"), "selector updates the in-memory model and level-only heading")
        check(controller.growth.companionDays == (points + 1) / 2, "demo companion days are explicit synthetic data")
        check(CatGrowthReward.allCases.filter(controller.isUnlocked).count == (level == 0 ? 0 : level == 3 ? 1 : 3), "selector cannot create extra rewards")
        check(controller.completionFeedback.text(at: app.now, available: true, blocked: false) == nil, "level switching never announces a goal")
        check(app.panel.frame == frame && app.art.pose == pose, "level switching never moves or deforms the cat")
        controller.window?.performClose(nil); controller.present()
        check(controller.growth.points == points, "reopening keeps the current in-memory demo")
    }
    check(prefs == UserDefaults.standard.persistentDomain(forName: "local.catcompanion.opensource") as NSDictionary?, "preview selector preserves real preferences")
    controller.window?.performClose(nil)
    print("PASS isolated preview selector: 0/3/10/30/37/50/100/110 and downgrade, nil storage, no speech/new rewards, retained in-memory state and pet geometry")
}
