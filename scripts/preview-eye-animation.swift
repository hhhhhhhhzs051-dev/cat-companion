import AppKit

private final class EyeAnimationCanvas: NSView {
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.96, alpha: 1).setFill(); bounds.fill()
    }
}

final class EyeAnimationStudy: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private(set) var window: NSWindow!
    private(set) var cat: NativeCatView!
    let player = EyeAnimationPlayer()
    private var left: NSButton!
    private var right: NSButton!
    private var reduced: NSButton!
    private var status: NSTextField!
    func applicationDidFinishLaunching(_ notification: Notification) {
        do { try start(resources: Bundle.main.resourceURL!) }
        catch { fputs("Eye animation preview failed: \(error)\n", stderr); NSApp.terminate(nil) }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationDidHide(_ notification: Notification) { player.cancel() }
    func applicationWillTerminate(_ notification: Notification) { player.cancel() }
    func windowWillClose(_ notification: Notification) { player.cancel() }
    func windowWillMiniaturize(_ notification: Notification) { player.cancel() }
    func windowDidResignKey(_ notification: Notification) { player.cancel() }
    func windowDidChangeOcclusionState(_ notification: Notification) {
        if !window.occlusionState.contains(.visible) { player.cancel() }
    }
    private func text(_ value: String, _ rect: NSRect, _ size: CGFloat = 13) -> NSTextField {
        let field = NSTextField(labelWithString: value)
        field.frame = rect; field.font = .systemFont(ofSize: size)
        field.textColor = .labelColor; window.contentView!.addSubview(field)
        return field
    }
    func start(resources: URL) throws {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 448),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "眼神轻移 · 手动动画预览 · 未安装（290pt）"
        window.isReleasedWhenClosed = false; window.delegate = self
        window.appearance = NSAppearance(named: .aqua)
        window.collectionBehavior = [.fullScreenNone]
        window.contentView = EyeAnimationCanvas(frame: NSRect(x: 0, y: 0, width: 520, height: 448))
        _ = text("正看 → 轻轻看一侧 → 回中", NSRect(x: 24, y: 16, width: 475, height: 27), 19)
        _ = text("原眼形 · 原幅度 · 不扩瞳 · 不叠加头动", NSRect(x: 24, y: 49, width: 475, height: 22))
        cat = try NativeCatView(resources: resources)
        cat.frame = NSRect(x: 115, y: 64, width: 290, height: 267)
        cat.setAccessibilityRole(.image); cat.setAccessibilityLabel("290pt眼神动画预览")
        cat.update(CatPose())
        window.contentView!.addSubview(cat)
        left = NSButton(title: "向左看一次", target: self, action: #selector(playLeft))
        right = NSButton(title: "向右看一次", target: self, action: #selector(playRight))
        for (button, x) in [(left!, 104.0), (right!, 270.0)] {
            button.frame = NSRect(x: x, y: 330, width: 146, height: 32)
            button.bezelStyle = .rounded; window.contentView!.addSubview(button)
        }
        reduced = NSButton(checkboxWithTitle: "减少动态（仅此预览）", target: self, action: #selector(updateMotionPreference))
        reduced.frame = NSRect(x: 24, y: 374, width: 275, height: 25)
        window.contentView!.addSubview(reduced)
        status = text("未播放 · 点击按钮开始", NSRect(x: 24, y: 410, width: 475, height: 22), 12)
        player.onChange = { [weak self] aim, playing in
            guard let self else { return }
            self.cat.eyeAim = aim
            self.left.isEnabled = !playing && !self.player.reducedMotion
            self.right.isEnabled = !playing && !self.player.reducedMotion
            self.status.stringValue = self.player.reducedMotion ? "减少动态：保持原画静止"
                : (playing ? "播放一次中 · 结束后自动停下" : "已回到原画 · 不循环，可手动再看一次")
        }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(updateMotionPreference),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        updateMotionPreference()
        if !player.reducedMotion { status.stringValue = "未播放 · 点击按钮开始" }
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func playLeft() { play(-1) }
    @objc func playRight() { play(1) }
    private func play(_ direction: Double) {
        guard window.isVisible, !window.isMiniaturized else { return }
        player.start(direction: direction)
    }
    @objc private func updateMotionPreference() {
        player.reducedMotion = reduced.state == .on || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        player.cancel()
    }
    deinit { NSWorkspace.shared.notificationCenter.removeObserver(self) }
}

func runEyeStudy() {
    precondition(Bundle.main.bundleIdentifier == "local.catcompanion.preview.rigid-eye-animation")
    let app = NSApplication.shared
    let delegate = EyeAnimationStudy(); app.delegate = delegate
    app.setActivationPolicy(.regular)
    let menu = NSMenu(), item = NSMenuItem(), appMenu = NSMenu()
    menu.addItem(item); item.submenu = appMenu
    appMenu.addItem(withTitle: "关闭眼神动画预览", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    app.mainMenu = menu; app.run()
    withExtendedLifetime(delegate) {}
}
