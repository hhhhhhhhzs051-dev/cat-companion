import AppKit

// A real 290pt window, real PetApp lifecycle and a newly-created temporary save.
// Unlike --self-test, this does NOT bypass WindowServer visibility in syncActivity.
// CAT_PLAY_PREVIEW prevents preference writes; applicationDidFinishLaunching is
// never called, so formal copy/storage and the installed app are never opened.
func runMenuTests(_ app: PetApp) {
    receiptCheck(app.isPlayPreview && !app.selfTest, "requires preview build without --self-test")
    NSApp.setActivationPolicy(.regular); NSApp.finishLaunching()
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("cat-space-receipt-" + UUID().uuidString)
    try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let store = CatGrowthStore(url: folder.appendingPathComponent("growth.json"))
    print("[receipt-space] isolated store: \(store.url.path)")
    let source = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("src")
    app.art = try! NativeCatView(resources: source)
    let screen = NSScreen.screens.first!.visibleFrame
    app.panel = PetPanel(contentRect: NSRect(x: screen.minX+60, y: screen.midY-100, width: 290, height: 267),
                         styleMask: [.borderless, .miniaturizable], backing: .buffered, defer: false)
    app.panel.title = "气泡跨桌面诊断 · 未安装（290pt）"
    app.panel.isOpaque = false; app.panel.backgroundColor = .clear; app.panel.hasShadow = false
    app.panel.level = .normal; app.panel.hidesOnDeactivate = false
    app.panel.collectionBehavior = [.fullScreenNone]; app.panel.isReleasedWhenClosed = false
    let container = NSView(frame: NSRect(x: 0, y: 0, width: 290, height: 267))
    app.panel.contentView = container; app.art.frame = container.bounds; container.addSubview(app.art)
    app.touch = PetTouchView(frame: container.bounds); app.touch.owner = app; container.addSubview(app.touch)
    app.setupControls(in: container)
    app.copy = ["pet": ["摸猫的普通短句。"]]
    let growth = CatGrowthController(owner: app, store: store); app.growthController = growth
    app.panel.delegate = app; app.settingsReady = true
    let coverRect = app.panel.convertToScreen(app.art.convert(NSRect(x: 0, y: 0, width: 290, height: 66), to: nil)).integral
    let cover = NSWindow(contentRect: coverRect, styleMask: .borderless, backing: .buffered, defer: false)
    cover.isReleasedWhenClosed = false; cover.isOpaque = true; cover.backgroundColor = .white
    cover.level = NSWindow.Level(rawValue: app.panel.level.rawValue+1)
    cover.collectionBehavior = [.fullScreenNone]; cover.hidesOnDeactivate = false
    if ProcessInfo.processInfo.environment["CAT_RECEIPT_SOLID_COVER"] == "1" {
        cover.contentView = ReceiptSolidCover(frame: NSRect(origin: .zero, size: coverRect.size))
    }
    let occlusionObserver = NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: nil, queue: .main) { note in
        guard let window = note.object as? NSWindow,
              window === app.panel || window === cover || window.parent === app.panel else { return }
        print("[receipt-occlusion] \(app.now) id=\(window.windowNumber) state=\(window.occlusionState.rawValue) space=\(window.isOnActiveSpace)"); fflush(stdout)
    }
    defer {
        NotificationCenter.default.removeObserver(occlusionObserver)
        app.settingsReady = false; app.panel.delegate = nil
        app.animationTimer?.invalidate(); app.stopPointerTracking()
        cover.orderOut(nil); app.panel.orderOut(nil)
        // Keep only this disposable fixture's evidence for diagnosis.
    }
    var receipts: [(String, Double)] = []
    var coveredReceiptScene: ReceiptWindowScene?
    var expectCover = true
    app.art.needsTextReceipt = { growth.completionFeedback.awaitsRender($0) }
    app.art.onTextRendered = { text in
        if expectCover {
            let scene = ReceiptWindowScene("covered-production-receipt", panel: app.panel, cover: cover)
            coveredReceiptScene = scene; scene.emit()
        }
        receipts.append((text, app.now)); growth.didRenderCompletion(text, at: app.now)
    }
    var lastState = ""
    func step() {
        while let event = NSApp.nextEvent(matching: .any, until: Date(), inMode: .default, dequeue: true) { NSApp.sendEvent(event) }
        NSApp.updateWindows()
        RunLoop.main.run(until: Date().addingTimeInterval(0.015))
        let state = "space=\(app.panel.isOnActiveSpace) active=\(app.active) occlusion=\(app.panel.occlusionState.rawValue) timer=\(app.animationTimer != nil) receipts=\(receipts.count) probes=\(app.panel.childWindows?.count ?? 0)"
        if state != lastState { print("[receipt-space] \(app.now) \(state)"); fflush(stdout); lastState = state }
    }
    func pump(_ duration: Double) { let end = app.now + duration; while app.now < end { step() } }
    func touch(_ type: NSEvent.EventType, _ point: CGPoint = CGPoint(x: 170, y: 112)) {
        let event = NSEvent.mouseEvent(with: type, location: NSPoint(x: point.x, y: 267-point.y), modifierFlags: [], timestamp: app.now,
                                      windowNumber: app.panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        switch type {
        case .leftMouseDown: app.touch.mouseDown(with: event)
        case .leftMouseDragged: app.touch.mouseDragged(with: event)
        default: app.touch.mouseUp(with: event)
        }
    }
    func requireUnconsumed() {
        growth.flushCompletionReceipt()
        receiptCheck(receipts.isEmpty && (try! store.load()!).completionShownDay == nil,
                     "hidden/covered completion consumed or saved without visibility")
        receiptCheck(growth.growth.points == 2, "test must genuinely complete both goals")
    }
    // A bare CLI test process has no LaunchServices activation. Activate only
    // during setup; NEVER activate/orderFront on the later Space return.
    NSApp.activate(ignoringOtherApps: true); app.panel.makeKeyAndOrderFront(nil)
    cover.orderFrontRegardless(); pump(0.5)
    receiptCheck(app.panel.isOnActiveSpace && app.active, "INVALID_SCENE: test window must start on visible desktop", code: 2)
    if let solid = cover.contentView as? ReceiptSolidCover {
        receiptCheck(solid.drawCount > 0, "INVALID_SCENE: opaque cover view has not drawn", code: 2)
        print("[receipt-space] solid cover drawn \(solid.drawCount) times")
    }
    let heldSpaceCycle = CommandLine.arguments.contains("--held-space-cycle")
    let liveSpaceCycle = CommandLine.arguments.contains("--space-cycle") || heldSpaceCycle
    app.toy.start(app.now); app.tick(); _ = app.toyKey(124)
    touch(.leftMouseDown); pump(0.1)
    if !heldSpaceCycle { touch(.leftMouseUp) }
    // Remove the ball's engaged tail so actual occlusion, not toy engagement,
    // determines activity during the Space transition. This is fixture setup.
    app.toy.finish(app.now, immediate: true); pump(0.7)
    if !receipts.isEmpty {
        (coveredReceiptScene ?? ReceiptWindowScene("missing-cover-evidence", panel: app.panel, cover: cover)).requireCover()
        receiptCheck(false, "covered completion wrongly acknowledged")
    }
    if heldSpaceCycle {
        // Independent lifecycle scenario: both tasks completed while contact is
        // still held. Completion has not reached draw yet. Switching Space must
        // cancel the actual contact, preserve eligibility, and require new input.
        // This is NOT a substitute/pass for the separate covered-draw scenario.
        receiptCheck(app.touch.hasContact && !growth.completionFeedback.awaitsRender(app.art.text), "held contact must gate initial completion")
    } else {
        receiptCheck(growth.completionFeedback.awaitsRender(app.art.text), "completion must await real draw, not merely be absent")
        ReceiptWindowScene("production-covered-pending", panel: app.panel, cover: cover).requireCover()
    }
    requireUnconsumed()

    if liveSpaceCycle {
        let originalID = app.panel.windowNumber
        print("READY_SWITCH_AWAY: switch to another ordinary Space, stay at least 5 seconds, then return; do not click either cat."); fflush(stdout)
        let awayDeadline = app.now + 180
        while app.panel.isOnActiveSpace && app.now < awayDeadline { step() }
        receiptCheck(!app.panel.isOnActiveSpace, "INCOMPLETE: no live Space departure observed", code: 2)
        let departed = app.now
        let backDeadline = app.now + 120
        var stableAwaySamples = 0
        while !app.panel.isOnActiveSpace && app.now < backDeadline {
            step()
            requireUnconsumed()
            // Re-evaluate AFTER pumping events. During the return animation,
            // occlusion can become visible before isOnActiveSpace catches up.
            // Production syncActivity follows occlusion, not Space membership.
            // Require suspension during the genuinely settled, invisible phase;
            // still require a sampled away phase and a fully resumed endpoint.
            if app.now-departed > 1 && !app.panel.isOnActiveSpace && !app.panel.occlusionState.contains(.visible) {
                receiptCheck(!app.active && app.animationTimer == nil, "Space departure did not suspend idle cat")
                receiptCheck(app.panel.childWindows?.isEmpty ?? true, "Space departure leaked visibility probe")
                receiptCheck(!app.touch.hasContact, "Space departure did not cancel held contact")
                stableAwaySamples += 1
            }
        }
        receiptCheck(app.panel.isOnActiveSpace && app.now-departed >= 2, "INCOMPLETE: need observable away and return interval", code: 2)
        receiptCheck(stableAwaySamples >= 5, "INCOMPLETE: no sustained invisible away phase sampled", code: 2)
        print("[receipt-space] validated suspended away samples=\(stableAwaySamples), awayDuration=\(app.now-departed)")
        pump(0.5)
        receiptCheck(app.panel.windowNumber == originalID && app.active && app.animationTimer != nil,
                     "same running window failed to resume after Space return")
        requireUnconsumed()
        receiptCheck(!growth.completionFeedback.awaitsRender(app.art.text), "Space return must not automatically re-arm completion")
        expectCover = false; cover.orderOut(nil); pump(0.5); requireUnconsumed()
        touch(.leftMouseDown); pump(0.1); touch(.leftMouseUp)
    } else {
        expectCover = false; cover.orderOut(nil)
    }
    let deadline = app.now + 1
    while receipts.isEmpty && app.now < deadline { step() }
    if receipts.isEmpty {
        ReceiptWindowScene("uncovered-no-receipt",panel:app.panel,cover:cover).emit()
        let rows=CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as! [[String:Any]]
        print("[receipt-debug] owned",NSApp.windows.map {($0.windowNumber,$0.isVisible,$0.styleMask.rawValue)})
        for row in rows.prefix(while:{($0[kCGWindowNumber as String] as? Int) != app.panel.windowNumber}) {
            print("[receipt-debug] front",row[kCGWindowNumber as String] as Any,row[kCGWindowLayer as String] as Any,row[kCGWindowBounds as String] as Any)
        }
        if let probe=app.panel.childWindows?.first {
            for x in [probe.frame.minX+1,probe.frame.midX,probe.frame.maxX-1] {
                for y in [probe.frame.minY+1,probe.frame.midY,probe.frame.maxY-1] {
                    print("[receipt-debug] hit",x,y,NSWindow.windowNumber(at:NSPoint(x:x,y:y),belowWindowWithWindowNumber:0))
                }
            }
        }
    }
    receiptCheck(receipts.count == 1, "visible deliberate interaction failed to deliver exactly once")
    let (line, shown) = receipts[0]
    receiptCheck(line.contains("第 1 天"), "wrong completion day")
    touch(.leftMouseDown)
    var lastVisible = shown
    while app.now-shown < 3.5 {
        touch(.leftMouseDragged, CGPoint(x: 170+sin((app.now-shown)*10)*7, y: 112)); step()
        if app.now-shown < 2.8 { receiptCheck(app.art.text == line, "ordinary pet speech replaced protected completion") }
        if app.art.text == line { lastVisible = app.now }
    }
    touch(.leftMouseUp); pump(0.1)
    receiptCheck((2.85...3.2).contains(lastVisible-shown), "completion did not remain stable approximately 3 seconds")
    for _ in 0..<3 { touch(.leftMouseDown); pump(0.05); touch(.leftMouseUp); pump(0.05) }
    growth.flushCompletionReceipt()
    let saved = try! store.load()!
    receiptCheck(receipts.count == 1 && saved.points == 2 && saved.completionShownDay == saved.day, "receipt must persist once without rescoring")
    receiptCheck(app.panel.childWindows?.isEmpty ?? true, "probe leaked after receipt")
    print("PASS real lifecycle 290pt receipt: \(liveSpaceCycle ? "\(heldSpaceCycle ? "held-input" : "covered-draw") pending + LIVE SPACE away/return + deliberate rearm" : "covered pending"), visible receipt once, stable \(String(format: "%.2f", lastVisible-shown))s, isolated persistence; no self-test visibility bypass")
}
