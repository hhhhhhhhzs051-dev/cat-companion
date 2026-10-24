import AppKit

// No PetApp, storage, settings, input monitor, animation clock or random action.
private final class EyeStudyCanvas:NSView {
    override var isFlipped:Bool {true}
    override func draw(_ dirtyRect:NSRect) {
        NSColor(calibratedWhite:0.96,alpha:1).setFill();bounds.fill()
    }
}

private final class EyeStudyApp:NSObject,NSApplicationDelegate {
    private var window:NSWindow!
    private var studies:[NativeCatView]=[]
    private var closure:NSButton!
    private var neutral:NSButton!
    private let names=["看左 · 小幅移动","正看 · 已验收原画","看右 · 小幅移动"]
    private let aims=[CatEyeAim(x:-1),CatEyeAim.neutral,CatEyeAim(x:1)]
    func applicationDidFinishLaunching(_ notification:Notification) {
        do {try start()} catch {fputs("Eye study failed: \(error)\n",stderr);NSApp.terminate(nil)}
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool {true}
    private func text(_ value:String,_ rect:NSRect,_ size:CGFloat=13)->NSTextField {
        let field=NSTextField(labelWithString:value);field.frame=rect
        field.font = .systemFont(ofSize:size);field.textColor = .labelColor
        window.contentView!.addSubview(field);return field
    }
    private func start() throws {
        precondition(Bundle.main.bundleIdentifier=="local.catcompanion.preview.rigid-eye-study")
        let resources=Bundle.main.resourceURL!
        window=NSWindow(contentRect:NSRect(x:0,y:0,width:958,height:430),
                        styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
        window.title="眼内整体移动 · 静态预览 · 未安装（每只290pt）"
        window.isReleasedWhenClosed=false
        window.appearance=NSAppearance(named:.aqua)
        window.collectionBehavior=[.fullScreenNone]
        window.contentView=EyeStudyCanvas(frame:NSRect(x:0,y:0,width:958,height:430))
        _=text("左、中、右 · 原眼内图案小幅移动",NSRect(x:24,y:16,width:850,height:30),19)
        for index in 0..<3 {
            let x=24.0+Double(index)*310
            _=text(names[index],NSRect(x:x,y:58,width:290,height:22))
            let view=try NativeCatView(resources:resources)
            view.frame=NSRect(x:x,y:76,width:290,height:267)
            // These are images for comparison, not misleading pet buttons.
            view.setAccessibilityRole(.image);view.setAccessibilityLabel(names[index])
            window.contentView!.addSubview(view)
            studies.append(view)
        }
        closure=NSButton(checkboxWithTitle:"对照完整闭眼",target:self,action:#selector(selectDirection))
        closure.frame=NSRect(x:24,y:354,width:190,height:26);window.contentView!.addSubview(closure)
        neutral=NSButton(checkboxWithTitle:"三只都显示原图（手动对照）",target:self,action:#selector(selectDirection))
        neutral.frame=NSRect(x:250,y:354,width:270,height:26);window.contentView!.addSubview(neutral)
        _=text("仅静态对照 · 不可摸猫或玩球 · 不扩瞳、不自动播放 · 不读写真实存档",
               NSRect(x:24,y:399,width:900,height:20),12)
        let menu=NSMenu(),item=NSMenuItem(),appMenu=NSMenu()
        menu.addItem(item);item.submenu=appMenu
        appMenu.addItem(withTitle:"关闭眼神预览",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
        NSApp.mainMenu=menu
        selectDirection()
        window.center();window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
    }
    @objc private func selectDirection() {
        let p=CatPose(eyes:closure.state == .on ? 1:0)
        for (index,view) in studies.enumerated() {
            view.update(p);view.eyeAim=neutral.state == .on ? .neutral:aims[index]
            view.setAccessibilityLabel(closure.state == .on ? "完整闭眼"
                : (neutral.state == .on ? "正看 · 已验收原画":names[index]))
        }
    }
}

func runEyeStudy() {
    let app=NSApplication.shared
    let delegate=EyeStudyApp();app.delegate=delegate;app.setActivationPolicy(.regular)
    app.run()
    withExtendedLifetime(delegate) {}
}
