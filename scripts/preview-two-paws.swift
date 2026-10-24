import AppKit

// Compile with CAT_MENU_TEST; reuse actual PetApp input, timing and renderer,
// but never call its normal launch/settings/migration path.
final class TwoPawPreview:NSObject,NSWindowDelegate {
    let pet:PetApp
    var timer:Timer?
    init(_ pet:PetApp) {self.pet=pet;super.init()}
    @objc func choose(_ sender:NSButton) {
        let time=pet.now
        if sender.tag==5 {pet.toy.start(time);pet.tick();return}
        let positions=[0.55,0.595,0.625,0.67,0.76]
        if !pet.toy.isOut {pet.toy.start(time)}
        pet.toy.grab(time)
        pet.toy.move(to:CGPoint(x:positions[sender.tag],y:0.37),at:time)
        pet.toy.release(time);pet.tick()
    }
    @objc func closePreview() {NSApp.terminate(nil)}
    func windowWillClose(_ notification:Notification) {timer?.invalidate();NSApp.terminate(nil)}
}

func runMenuTests(_ pet:PetApp) {
    guard pet.selfTest else {fputs("Preview requires --self-test; refusing normal launch\n",stderr);exit(1)}
    let controller=TwoPawPreview(pet)
    NSApp.setActivationPolicy(.regular)
    let menu=NSMenu(),item=NSMenuItem(),submenu=NSMenu()
    let quit=NSMenuItem(title:"关闭预览",action:#selector(TwoPawPreview.closePreview),keyEquivalent:"q")
    quit.target=controller;submenu.addItem(quit);item.submenu=submenu;menu.addItem(item);NSApp.mainMenu=menu
    pet.art=try! NativeCatView(resources:pet.resources)
    pet.art.frame=NSRect(x:115,y:150,width:290,height:267)
    pet.panel=PetPanel(contentRect:NSRect(x:0,y:0,width:520,height:470),styleMask:[.titled,.closable],backing:.buffered,defer:false)
    pet.panel.title="左右爪预览 · 勾近微调 · 未安装（290pt）"
    // This preview has a fixed cream canvas; keep its native labels and buttons
    // readable even when the system switches appearance. No global preference.
    pet.panel.appearance=NSAppearance(named:.aqua)
    pet.panel.isReleasedWhenClosed=false;pet.panel.delegate=controller
    pet.panel.backgroundColor=NSColor(calibratedRed:0.97,green:0.95,blue:0.91,alpha:1)
    let root=NSView(frame:NSRect(x:0,y:0,width:520,height:470))
    pet.panel.contentView=root;root.addSubview(pet.art)
    pet.touch=PetTouchView(frame:pet.art.frame);pet.touch.owner=pet;root.addSubview(pet.touch)
    pet.touch.allowsContextMenu=false
    // No development/context menu in the preview; all relevant actions have
    // explicit buttons, while left-click petting and drag ownership are real.
    pet.art.onPet={pet.pet()};pet.art.onToyKey={pet.toyKey($0)}
    let title=NSTextField(labelWithString:"勾近稍向外侧 · 推远保持不变")
    title.font=NSFont.systemFont(ofSize:17,weight:.medium);title.alignment = .center
    title.frame=NSRect(x:20,y:426,width:480,height:25);root.addSubview(title)
    let note=NSTextField(wrappingLabelWithString:"画面左侧用猫右爪，画面右侧用猫左爪。\n可点按钮或直接拖球；未安装，不会保存设置。")
    note.alignment = .center;note.font=NSFont.systemFont(ofSize:12);note.textColor = .secondaryLabelColor
    note.frame=NSRect(x:25,y:100,width:470,height:39);root.addSubview(note)
    for (n,text) in ["左侧勾近","左侧推远","右侧推远","右侧勾近","远处只看","拿出小球"].enumerated() {
        let b=NSButton(title:text,target:controller,action:#selector(TwoPawPreview.choose(_:)))
        b.bezelStyle = .rounded;b.tag=n
        b.frame=NSRect(x:31+(n%3)*155,y:55-(n/3)*36,width:148,height:30);root.addSubview(b)
    }
    pet.settingsReady=false;pet.active=true;pet.petVisible=true;pet.paused=false
    pet.motion=CatMotion(now:pet.now,seed:7)
    // The same 30Hz clock, no preset automatically starts or repeats.
    controller.timer=Timer.scheduledTimer(withTimeInterval:1.0/30,repeats:true){_ in pet.tick()}
    pet.tick();pet.panel.center();pet.panel.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps:true)
    withExtendedLifetime(controller){NSApp.run()}
}
