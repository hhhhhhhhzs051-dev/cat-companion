import AppKit

private final class VariationAnimationCanvas:NSView {
    override var isFlipped:Bool {true}
    override func draw(_ dirtyRect:NSRect){NSColor(calibratedWhite:0.96,alpha:1).setFill();bounds.fill()}
}

final class VariationAnimationStudy:NSObject,NSApplicationDelegate,NSWindowDelegate {
    private(set) var window:NSWindow!
    private(set) var cat:NativeCatView!
    let player=EyeVariationPlayer()
    private var buttons:[NSButton]=[]
    private var reduced:NSButton!
    private var status:NSTextField!
    func applicationDidFinishLaunching(_ notification:Notification){
        do {try start(resources:Bundle.main.resourceURL!)}
        catch {fputs("Eye variation animation failed: \(error)\n",stderr);NSApp.terminate(nil)}
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool {true}
    func applicationDidHide(_ notification:Notification){player.cancel()}
    func applicationWillTerminate(_ notification:Notification){player.cancel()}
    func windowWillClose(_ notification:Notification){player.cancel()}
    func windowWillMiniaturize(_ notification:Notification){player.cancel()}
    func windowDidResignKey(_ notification:Notification){player.cancel()}
    func windowDidChangeOcclusionState(_ notification:Notification){
        if !window.occlusionState.contains(.visible){player.cancel()}
    }
    @discardableResult private func text(_ value:String,_ rect:NSRect,_ size:CGFloat=13)->NSTextField {
        let f=NSTextField(labelWithString:value);f.frame=rect;f.font = .systemFont(ofSize:size)
        f.textColor = .labelColor;window.contentView!.addSubview(f);return f
    }
    func start(resources:URL) throws {
        window=NSWindow(contentRect:NSRect(x:0,y:0,width:540,height:470),
            styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
        window.title="瞳孔25%／40% · 对照动画预览 · 未安装（290pt）"
        window.isReleasedWhenClosed=false;window.delegate=self
        window.appearance=NSAppearance(named:.aqua);window.collectionBehavior=[.fullScreenNone]
        window.contentView=VariationAnimationCanvas(frame:NSRect(x:0,y:0,width:540,height:470))
        text("瞳孔宽度，两档对照",NSRect(x:24,y:16,width:490,height:27),19)
        text("原图 → 略宽 → 恢复 · 不转眼、不加头动 · 时长相同",NSRect(x:24,y:49,width:490,height:22),12)
        cat=try NativeCatView(resources:resources);cat.frame=NSRect(x:125,y:64,width:290,height:267)
        cat.update(CatPose());cat.setAccessibilityRole(.image);cat.setAccessibilityLabel("290pt眼部单次动画预览")
        window.contentView!.addSubview(cat)
        for (title,action,x) in [("播放 +25%（对照）",#selector(playPupil),96.0),
                                  ("播放 +40%（增强）",#selector(playPupilWide),284.0)] {
            let b=NSButton(title:title,target:self,action:action);b.bezelStyle = .rounded
            b.frame=NSRect(x:x,y:330,width:160,height:32);window.contentView!.addSubview(b);buttons.append(b)
        }
        reduced=NSButton(checkboxWithTitle:"减少动态（仅此预览）",target:self,action:#selector(updateMotionPreference))
        reduced.frame=NSRect(x:24,y:377,width:285,height:25);window.contentView!.addSubview(reduced)
        let reset=NSButton(title:"停止并恢复原图",target:self,action:#selector(stop))
        reset.frame=NSRect(x:356,y:374,width:160,height:32);reset.bezelStyle = .rounded;window.contentView!.addSubview(reset)
        status=text("未播放 · 请手动选择一项",NSRect(x:24,y:417,width:490,height:22),12)
        text("不循环 · 不可摸猫或玩球 · 不读写真实存档",NSRect(x:24,y:446,width:490,height:20),11)
        player.onChange={[weak self] value,playing in
            guard let self else{return}
            self.cat.eyeVariation=value
            self.buttons.forEach{$0.isEnabled = !playing && !self.player.reducedMotion}
            self.status.stringValue=self.player.reducedMotion ? "减少动态：保持原图静止":
                (playing ? "播放一次中 · 稍作停留后自然恢复":"已恢复原图 · 不循环，可手动重播")
        }
        NSWorkspace.shared.notificationCenter.addObserver(self,selector:#selector(updateMotionPreference),
            name:NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,object:nil)
        updateMotionPreference()
        window.center();window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
        if !player.reducedMotion {status.stringValue="未播放 · 请手动选择一项"}
    }
    @objc func playLeft(){play(.left)}
    @objc func playRight(){play(.right)}
    @objc func playPupil(){play(.pupil)}
    @objc func playPupilWide(){play(.pupilWide)}
    private func play(_ action:EyeVariationAction){
        // An explicit accessibility button press need not make the window key.
        // It is still manual input; invisible/minimized windows cannot start.
        guard window.isVisible,!window.isMiniaturized,window.occlusionState.contains(.visible) else{return}
        player.start(action)
    }
    @objc private func stop(){player.cancel()}
    @objc private func updateMotionPreference(){
        player.reducedMotion=reduced.state == .on || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        player.cancel()
    }
    deinit{NSWorkspace.shared.notificationCenter.removeObserver(self)}
}

func runEyeStudy(){
    precondition(Bundle.main.bundleIdentifier=="local.catcompanion.preview.pupil-width-comparison")
    let app=NSApplication.shared,delegate=VariationAnimationStudy();app.delegate=delegate;app.setActivationPolicy(.regular)
    let menu=NSMenu(),item=NSMenuItem(),appMenu=NSMenu();menu.addItem(item);item.submenu=appMenu
    appMenu.addItem(withTitle:"关闭眼部动画预览",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
    app.mainMenu=menu;app.run();withExtendedLifetime(delegate) {}
}
