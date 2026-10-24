import AppKit

// Standalone manual animation study: no PetApp, settings, copy, migrations,
// network, automatic loops or rejected outer-paw artwork.
private final class AnimationCanvas: NSView { override var isFlipped: Bool { true } }
private final class AnimationWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) { performClose(sender) }
}

private final class PawAnimationApp: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: AnimationWindow!
    private var cat: NativeCatView!
    private var picture: NSImageView!
    private var player = OriginalPawPlayback()
    private var timer: Timer?
    private var demoButtons: [NSButton] = []
    private var pauseButton: NSButton!
    private var reducedButton: NSButton!
    private var status: NSTextField!
    private var clock: () -> Double = { ProcessInfo.processInfo.systemUptime }
    private var testing = false
    private var systemReduced: Bool { !testing && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    private var reduced: Bool { systemReduced || reducedButton.state == .on }

    func applicationDidFinishLaunching(_ notification: Notification) {
        do { try start() }
        catch { fputs("FAIL animation preview: \(error)\n", stderr); exit(1) }
    }
    private func label(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat,
                       size: CGFloat = 13, primary: Bool = false) {
        let field = NSTextField(labelWithString: text)
        field.frame = NSRect(x: x, y: y, width: width, height: 24)
        field.font = .systemFont(ofSize: size)
        field.textColor = primary ? .labelColor : .secondaryLabelColor
        window.contentView!.addSubview(field)
    }
    private func start() throws {
        precondition(Bundle.main.bundleIdentifier == "local.catcompanion.preview.original-paw-motion")
        let resources = Bundle.main.resourceURL!
        precondition(!FileManager.default.fileExists(atPath: resources.appendingPathComponent("assets/cat-paw-outer-v2.png").path))
        cat = try NativeCatView(resources: resources)
        guard let art = cat.pawArt,
              art.overlay(PawPose(raise: 1, toyElbow: 0.04, toyWrist: -1.37, toySide: -1)) != nil else {
            throw NSError(domain: "PawAnimationPreview", code: 1, userInfo: [NSLocalizedDescriptionKey: "Original paw overlay unavailable"])
        }
        let menu = NSMenu(), item = NSMenuItem(), appMenu = NSMenu()
        menu.addItem(item); item.submenu = appMenu
        appMenu.addItem(withTitle: "隐藏预览", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "关闭预览", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = menu
        window = AnimationWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 410),
                                 styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "勾近间距微调 2 · 动画预览 · 未安装（290pt）"
        window.delegate = self; window.isReleasedWhenClosed = false; window.isRestorable = false
        window.collectionBehavior = [.fullScreenNone]; window.animationBehavior = .none
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(srgbRed: 0.14, green: 0.16, blue: 0.17, alpha: 1)
        window.contentView = AnimationCanvas(frame: NSRect(x: 0, y: 0, width: 640, height: 410))
        label("原版爪形 · 正常大小动画", x: 24, y: 18, width: 580, size: 20, primary: true)
        label("手动播放一次，结束后静止。以下控件只用于预览。", x: 24, y: 51, width: 590)
        // Use exactly the accepted still study's detached rendering context.
        // AppKit's attached view context changes the contact-shadow raster.
        // Retain one displayed frame only; never precompute/keep an animation.
        cat.frame = NSRect(x: 0, y: 0, width: 290, height: 267)
        picture = NSImageView(frame: NSRect(x: 20, y: 76, width: 290, height: 267))
        picture.imageScaling = .scaleNone
        picture.setAccessibilityLabel("原版爪形动画，正常290pt")
        window.contentView!.addSubview(picture)
        label("爪尖再向外一点 · 第二次微调", x: 338, y: 92, width: 270, primary: true)
        for demo in PawDemo.allCases {
            let button = NSButton(title: demo.title, target: self, action: #selector(playDemo(_:)))
            button.tag = demo.rawValue; button.bezelStyle = .rounded
            let row = demo.rawValue / 2
            button.frame = NSRect(x: 334 + (demo.rawValue % 2) * 140,
                                 y: row == 0 ? 122 : 182 + row * 38, width: 134, height: 32)
            button.keyEquivalent = String(demo.rawValue + 1)
            window.contentView!.addSubview(button); demoButtons.append(button)
        }
        label("已验收中心动作对照", x: 338, y: 190, width: 270, primary: true)
        pauseButton = NSButton(title: "暂停", target: self, action: #selector(togglePause))
        pauseButton.bezelStyle = .rounded; pauseButton.frame = NSRect(x: 334, y: 306, width: 134, height: 32)
        pauseButton.keyEquivalent = " "
        window.contentView!.addSubview(pauseButton)
        reducedButton = NSButton(checkboxWithTitle: "减少动态", target: self, action: #selector(reducedChanged))
        reducedButton.frame = NSRect(x: 478, y: 309, width: 130, height: 26)
        window.contentView!.addSubview(reducedButton)
        status = NSTextField(labelWithString: "")
        status.frame = NSRect(x: 24, y: 350, width: 590, height: 22)
        status.font = .systemFont(ofSize: 13); status.textColor = .secondaryLabelColor
        window.contentView!.addSubview(status)
        label("身体不摇、爪长不变；正式 48 版未动。", x: 24, y: 380, width: 590, size: 12)
        drawFrame(); updateControls()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(accessibilityChanged(_:)),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)

        if let i = CommandLine.arguments.firstIndex(of: "--verify-static"), i + 1 < CommandLine.arguments.count {
            try verifyStatic(URL(fileURLWithPath: CommandLine.arguments[i + 1]))
            NSApp.terminate(nil); return
        }
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        if CommandLine.arguments.contains("--self-test") { runSelfTest() }
    }

    private func drawFrame(_ override: PreOuterFrame? = nil) {
        let f = override ?? player.frame
        var ball = CatToyFrame()
        ball.position = f.position; ball.opacity = f.opacity; ball.rotation = f.rotation
        ball.paw = f.paw; ball.pawSide = f.pawSide
        cat.toyFrame = ball
        var p = CatPose()
        p.paw = PawPose(raise: f.paw, toyElbow: f.pawElbow, toyWrist: f.pawWrist,
                       toySide: f.pawSide)
        cat.update(p)
        let image = NSImage(size: cat.bounds.size)
        image.addRepresentation(bitmap())
        picture.image = image
    }
    private func updateControls() {
        demoButtons.forEach { $0.isEnabled = !player.isPlaying }
        pauseButton.isEnabled = !reduced && (player.isPlaying || player.isPaused)
        pauseButton.title = player.isPaused ? "继续" : "暂停"
        if reduced { status.stringValue = "减少动态：点击示例只看静态接触姿势。" }
        else if player.isPlaying { status.stringValue = "\(player.demo.title) · 播放中" }
        else if player.isPaused { status.stringValue = "已暂停；点「继续」从当前姿势接着看。" }
        else { status.stringValue = "点右侧示例播放；左侧球用猫右爪，右侧球用猫左爪。" }
    }
    private func synchronizeTimer() {
        if !player.isPlaying { timer?.invalidate(); timer = nil; return }
        guard timer == nil else { return }
        let value = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            self?.advance()
        }
        value.tolerance = 0.001
        RunLoop.main.add(value, forMode: .common); timer = value
    }
    private func advance() {
        autoreleasepool {
            player.tick(clock()); drawFrame()
            // Release per-frame temporary Core Image/AppKit allocations here.
            picture.displayIfNeeded()
        }
        synchronizeTimer(); updateControls()
    }
    @objc private func playDemo(_ sender: NSButton) {
        guard let demo = PawDemo(rawValue: sender.tag), player.play(demo, at: clock(), reduced: reduced) else { return }
        drawFrame(); synchronizeTimer(); updateControls()
    }
    @objc private func togglePause() {
        if player.isPlaying { player.pause(clock()) } else { player.resume(clock()) }
        drawFrame(); synchronizeTimer(); updateControls()
    }
    @objc private func reducedChanged() {
        player.setReduced(reduced, at: clock())
        drawFrame(); synchronizeTimer(); updateControls()
    }
    @objc private func accessibilityChanged(_ notification: Notification) { reducedChanged() }
    private func suspend() {
        player.pause(clock()); drawFrame(); synchronizeTimer(); updateControls()
    }
    func applicationDidResignActive(_ notification: Notification) { if cat != nil { suspend() } }
    func applicationDidHide(_ notification: Notification) { if cat != nil { suspend() } }
    func windowDidChangeOcclusionState(_ notification: Notification) {
        if !window.occlusionState.contains(.visible) { suspend() }
    }
    func windowWillClose(_ notification: Notification) { player.stop(); synchronizeTimer() }
    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate(); timer = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func bitmap() -> NSBitmapImageRep {
        let value = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 580, pixelsHigh: 534,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        value.size = cat.bounds.size; cat.cacheDisplay(in: cat.bounds, to: value)
        return value
    }
    private func verifyStatic(_ folder: URL) throws {
        let diagnostics: URL? = {
            guard let i = CommandLine.arguments.firstIndex(of: "--diagnostics"), i + 1 < CommandLine.arguments.count else { return nil }
            return URL(fileURLWithPath: CommandLine.arguments[i + 1])
        }()
        if let diagnostics { try FileManager.default.createDirectory(at: diagnostics, withIntermediateDirectories: true) }
        func png() -> Data {
            (picture.image!.representations[0] as! NSBitmapImageRep).representation(using: .png, properties: [:])!
        }
        for (demo, name) in [(PawDemo.outerLeft, "left"), (.outerRight, "right")] {
            for (age, phase, oldWrist) in [(0.3744, "extend", -1.175), (0.52, "contact", -1.37), (0.82, "retract", -0.5681141998497371)] {
                player.stop(); _ = player.play(demo, at: 0); player.tick(age)
                // Verify the unchanged renderer, attachment, elbow, body and
                // ball against all six accepted stills with their old wrist.
                var baseline = player.frame; baseline.pawWrist = oldWrist
                drawFrame(baseline)
                let bytes = png()
                let a = NSBitmapImageRep(data: bytes)!
                let b = NSBitmapImageRep(data: try Data(contentsOf: folder.appendingPathComponent("candidate-\(name)-\(phase).png")))!
                guard a.pixelsWide == b.pixelsWide && a.pixelsHigh == b.pixelsHigh && a.bytesPerRow == b.bytesPerRow else {
                    throw NSError(domain: "PawStaticCheck", code: 1, userInfo: [NSLocalizedDescriptionKey: "Layout mismatch: new \(a.pixelsWide)x\(a.pixelsHigh) stride\(a.bytesPerRow), old \(b.pixelsWide)x\(b.pixelsHigh) stride\(b.bytesPerRow)"])
                }
                let size = a.bytesPerRow * a.pixelsHigh
                let newBytes = Data(bytes: a.bitmapData!, count: size), oldBytes = Data(bytes: b.bitmapData!, count: size)
                if newBytes != oldBytes {
                    if let diagnostics { try bytes.write(to: diagnostics.appendingPathComponent("failed-baseline-\(name)-\(phase).png")) }
                    let different = zip(newBytes, oldBytes).filter { $0 != $1 }.count
                    throw NSError(domain: "PawStaticCheck", code: 2, userInfo: [NSLocalizedDescriptionKey: "Keyframe mismatch \(name) \(phase): \(different)/\(size) bytes, newformat\(a.bitmapFormat.rawValue), oldformat\(b.bitmapFormat.rawValue)"])
                }
                drawFrame()
                let refinedPNG = png(), refined = NSBitmapImageRep(data: refinedPNG)!
                let refinedBytes = Data(bytes: refined.bitmapData!, count: size)
                guard (phase == "retract") == (refinedBytes == oldBytes) else {
                    throw NSError(domain: "PawStaticCheck", code: 3, userInfo: [NSLocalizedDescriptionKey: "Refinement must change preparation/contact pixels only, preserving the exact return: \(name) \(phase)"])
                }
                if let diagnostics {
                    try refinedPNG.write(to: diagnostics.appendingPathComponent("refined-\(name)-\(phase).png"))
                }
            }
        }
        print("PASS six baseline keyframes pixel-identical; four refined preparation/contact frames visibly changed; both return frames pixel-identical")
    }
    private func runSelfTest() {
        testing = true
        var time = 100.0; clock = { time }
        precondition(timer == nil && !player.isPlaying && picture.frame.size == NSSize(width: 290, height: 267))
        demoButtons[0].performClick(nil)
        precondition(timer != nil && player.isPlaying)
        time += 0.52; advance()
        precondition(abs(cat.pose.paw.toyElbow! - 0.04) < 1e-9 && cat.pose.breath == 0 && cat.pose.lean == 0)
        pauseButton.performClick(nil)
        precondition(timer == nil && player.isPaused)
        let held = cat.pose; time += 30; advance()
        precondition(cat.pose == held)
        pauseButton.performClick(nil); advance()
        precondition(timer != nil && cat.pose == held)
        time += 1.3; advance()
        precondition(timer == nil && !player.isPlaying && cat.pose.paw.raise == 0)
        demoButtons[1].performClick(nil); time += 0.3
        applicationDidResignActive(Notification(name: NSApplication.didResignActiveNotification))
        precondition(timer == nil && player.isPaused)
        reducedButton.performClick(nil); demoButtons[1].performClick(nil)
        precondition(timer == nil && !player.isPlaying && !pauseButton.isEnabled)
        reducedButton.performClick(nil)
        precondition(timer == nil && !player.isPlaying)
        var renderTimes: [Double] = []
        for button in demoButtons {
            player.stop(); button.performClick(nil)
            for _ in 0..<40 {
                time += 1.0 / 30
                let start = ProcessInfo.processInfo.systemUptime
                advance()
                renderTimes.append(ProcessInfo.processInfo.systemUptime - start)
            }
            precondition(timer == nil && !player.isPlaying && picture.image!.representations.count == 1)
        }
        renderTimes.sort()
        print("Render check 240 frames: p50 \(renderTimes[120] * 1000)ms, p95 \(renderTimes[228] * 1000)ms; not a live frame-rate benchmark")
        window.performClose(nil)
        precondition(!window.isVisible && timer == nil)
        print("PASS UI harness: explicit one-shot, 290pt, pause/resume, inactive handler, reduced motion, no idle timer, close")
        NSApp.terminate(nil)
    }
}

@main private struct OriginalPawAnimationPreview {
    static func main() {
        let app = NSApplication.shared, delegate = PawAnimationApp()
        app.setActivationPolicy(.regular); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
