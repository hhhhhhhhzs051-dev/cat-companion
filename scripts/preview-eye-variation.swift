import AppKit

// Separate app entry: no PetApp, save controllers, event monitors or timers.
private final class VariationCanvas:NSView {
    override var isFlipped:Bool {true}
    override func draw(_ dirtyRect:NSRect) {NSColor(calibratedWhite:0.96,alpha:1).setFill();bounds.fill()}
}

private final class VariationApp:NSObject,NSApplicationDelegate {
    private var window:NSWindow!
    private var cats:[NativeCatView]=[]
    private var mode:NSSegmentedControl!
    private var direction:NSSegmentedControl!
    private var amount:NSSegmentedControl!
    private var closure:NSButton!
    private var original:NSButton!
    private var descriptionLabel:NSTextField!
    func applicationDidFinishLaunching(_ notification:Notification) {
        do {try start()} catch {fputs("Eye variation study failed: \(error)\n",stderr);NSApp.terminate(nil)}
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool {true}
    @discardableResult private func label(_ value:String,_ rect:NSRect,_ size:CGFloat=13)->NSTextField {
        let f=NSTextField(labelWithString:value);f.frame=rect;f.font = .systemFont(ofSize:size)
        f.textColor = .labelColor;window.contentView!.addSubview(f);return f
    }
    private func start() throws {
        precondition(Bundle.main.bundleIdentifier=="local.catcompanion.preview.eye-variation")
        window=NSWindow(contentRect:NSRect(x:0,y:0,width:654,height:500),
            styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
        window.title="眼神与瞳孔 · 静态对照 · 未安装（290pt）"
        window.isReleasedWhenClosed=false;window.appearance=NSAppearance(named:.aqua)
        window.collectionBehavior=[.fullScreenNone]
        window.contentView=VariationCanvas(frame:NSRect(x:0,y:0,width:654,height:500))
        label("先看自然，再看明显程度",NSRect(x:24,y:16,width:600,height:26),19)
        label("左：正式62档",NSRect(x:24,y:55,width:290,height:22))
        label("右：独立试验档",NSRect(x:340,y:55,width:290,height:22))
        for x in [24.0,340.0] {
            let cat=try NativeCatView(resources:Bundle.main.resourceURL!)
            cat.frame=NSRect(x:x,y:76,width:290,height:267)
            cat.setAccessibilityRole(.image)
            cat.setAccessibilityLabel(x<100 ? "正式62眼神对照":"独立眼部试验")
            window.contentView!.addSubview(cat);cats.append(cat)
        }
        mode=NSSegmentedControl(labels:["只看眼神幅度","只看瞳孔宽窄"],trackingMode:.selectOne,target:self,action:#selector(changeMode))
        mode.frame=NSRect(x:24,y:351,width:282,height:26);mode.selectedSegment=0;window.contentView!.addSubview(mode)
        amount=NSSegmentedControl(labels:["增加20%","增加33%"],trackingMode:.selectOne,target:self,action:#selector(update))
        amount.frame=NSRect(x:348,y:351,width:280,height:26);amount.selectedSegment=0;window.contentView!.addSubview(amount)
        direction=NSSegmentedControl(labels:["看左","正看","看右"],trackingMode:.selectOne,target:self,action:#selector(update))
        direction.frame=NSRect(x:24,y:387,width:282,height:26);direction.selectedSegment=2;window.contentView!.addSubview(direction)
        original=NSButton(checkboxWithTitle:"两只恢复正看原图",target:self,action:#selector(update))
        original.frame=NSRect(x:348,y:387,width:276,height:26);window.contentView!.addSubview(original)
        closure=NSButton(checkboxWithTitle:"对照完整闭眼",target:self,action:#selector(update))
        closure.frame=NSRect(x:24,y:423,width:180,height:24);window.contentView!.addSubview(closure)
        descriptionLabel=label("",NSRect(x:215,y:426,width:420,height:20),12)
        label("手动静态对照 · 无头动/动画 · 不可摸猫或玩球 · 不读写真实存档",NSRect(x:24,y:474,width:620,height:20),11)
        let menu=NSMenu(),item=NSMenuItem(),appMenu=NSMenu();menu.addItem(item);item.submenu=appMenu
        appMenu.addItem(withTitle:"关闭眼部对照预览",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
        NSApp.mainMenu=menu
        update();window.center();window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
    }
    @objc private func changeMode() {
        let pupil=mode.selectedSegment==1
        amount.setLabel(pupil ? "略宽15%":"增加20%",forSegment:0)
        amount.setLabel(pupil ? "略宽25%":"增加33%",forSegment:1)
        amount.selectedSegment=0;direction.isEnabled = !pupil
        original.state = .off;update()
    }
    @objc private func update() {
        let pupil=mode.selectedSegment==1,restore=original.state == .on
        let x=pupil || restore ? 0:Double(direction.selectedSegment-1)
        cats[0].eyeAim=CatEyeAim(x:x,gain:1.125)
        cats[1].eyeVariation=restore ? .neutral:EyeVariation(direction:x,
            gain:amount.selectedSegment==0 ? 1.35:1.5,
            pupilWidth:pupil ? (amount.selectedSegment==0 ? 1.15:1.25):1)
        for cat in cats {cat.update(CatPose(eyes:closure.state == .on ? 1:0))}
        descriptionLabel.stringValue=pupil ? "瞳孔略宽试验；不叠加转向。":"只增加眼内位移；瞳孔形状不变。"
    }
}

func runEyeStudy() {
    let app=NSApplication.shared,delegate=VariationApp();app.delegate=delegate
    app.setActivationPolicy(.regular);app.run();withExtendedLifetime(delegate) {}
}
