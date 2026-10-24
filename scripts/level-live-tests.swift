import AppKit

// Exercise PetApp.tick with monotonic wall time, not injected future timestamps.
func runMenuTests(_ app: PetApp) {
    func check(_ result: Bool, _ message: String) { if !result { fputs("FAIL: \(message)\n", stderr); exit(1) } }
    let source = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("src")
    app.art = try! NativeCatView(resources: source)
    app.panel = PetPanel(contentRect: NSRect(x: 0, y: 0, width: 290, height: 267), styleMask: [.borderless], backing: .buffered, defer: false)
    let container = NSView(frame: NSRect(origin: .zero, size: app.panel.frame.size)); app.panel.contentView = container
    app.art.frame = container.bounds; container.addSubview(app.art)
    app.touch = PetTouchView(frame: container.bounds); app.touch.owner = app; container.addSubview(app.touch)
    app.active = true; app.motion = CatMotion(now: app.now, seed: 12)
    app.copy = ["pet": ["原来的摸头短句。"]]
    let growth = CatGrowthController(owner: app); app.growthController = growth
    // Complete play first with the actual keyboard handler; no growth window exists.
    app.toy.start(app.now); app.tick(); _ = app.toyKey(124)
    let onlyPlay = app.now
    while app.now - onlyPlay < 5 {
        app.tick()
        check(!app.art.text.contains("第 1 天"), "one completed goal must stay silent across real runtime ticks")
        RunLoop.current.run(until: Date().addingTimeInterval(0.015))
    }
    check(growth.window == nil && growth.growth.points == 1, "play scored without ever opening growth")
    app.pet(); let start = app.now, originalEnd = app.motion.petEnd
    var first: Double?, last: Double?, appearances = 0, wasShowing = false
    while app.now - start < 5.5 {
        app.tick()
        let elapsed = app.now - start
        let showing = app.art.text.contains("第 1 天")
        if showing {
            // This harness validates timing with an explicit paint acknowledgement;
            // the separate window test validates the native draw callback itself.
            growth.didRenderCompletion(app.art.text, at: app.now)
            if !wasShowing { appearances += 1 }
            first = first ?? elapsed; last = elapsed
        }
        if elapsed < 1.8 { check(showing && app.motion.petEnd == originalEnd, "completion replaces ordinary speech while original head response continues") }
        wasShowing = showing
        RunLoop.current.run(until: Date().addingTimeInterval(0.015))
    }
    check(appearances == 1 && first != nil && last != nil, "actual timer pipeline presents completion exactly once")
    check(first! < 0.1 && last! - first! >= 2.85 && last! - first! <= 3.15, "released completion is immediate and remains about three seconds after acknowledgement")
    check(app.art.text.isEmpty && app.motion.petEnd == originalEnd && growth.growth.points == 2 && growth.window == nil, "real completion ends quietly without mutating action timing or scoring or requiring a panel")
    app.pet(); let repeatStart = app.now
    while app.now - repeatStart < 2.3 {
        app.tick(); check(!app.art.text.contains("第 1 天"), "later real input cannot repeat today's completion")
        RunLoop.current.run(until: Date().addingTimeInterval(0.015))
    }
    print("PASS level live tick: first goal silent, second goal speaks immediately without panel, original action clock preserved, actual visible duration \(String(format: "%.2f", last! - first!))s, no repeated completion or action timing change")
}
