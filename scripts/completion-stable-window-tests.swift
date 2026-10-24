import AppKit

// Real drawing + real handler dispatch in this isolated 290pt window. No global
// mouse synthesis, production app interaction, or production preferences/store.
func runMenuTests(_ app: PetApp) {
    NSApp.setActivationPolicy(.accessory); NSApp.finishLaunching()
    let folder=FileManager.default.temporaryDirectory.appendingPathComponent("cat-stable-window-"+UUID().uuidString)
    try! FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
    defer {try? FileManager.default.removeItem(at:folder)}
    let store=CatGrowthStore(url:folder.appendingPathComponent("growth.json"))
    let source=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("src")
    app.art=try! NativeCatView(resources:source)
    app.art.bedCacheEnabled=ProcessInfo.processInfo.environment["CAT_TEST_BED_CACHE"] == "1"
    let screen=NSScreen.screens.first!.visibleFrame
    app.panel=PetPanel(contentRect:NSRect(x:screen.minX+60,y:screen.midY-100,width:290,height:267),styleMask:.borderless,backing:.buffered,defer:false)
    let container=NSView(frame:NSRect(x:0,y:0,width:290,height:267))
    app.panel.contentView=container; app.art.frame=container.bounds; container.addSubview(app.art)
    app.touch=PetTouchView(frame:container.bounds); app.touch.owner=app; container.addSubview(app.touch)
    app.active=true; app.motion=CatMotion(now:app.now,seed:12)
    app.copy=["pet":["摸猫的普通短句。"]]
    let growth=CatGrowthController(owner:app,store:store); app.growthController=growth
    var receipts:[(String,Double)]=[]
    app.art.needsTextReceipt={growth.completionFeedback.awaitsRender($0)}
    app.art.onTextRendered={text in receipts.append((text,app.now));growth.didRenderCompletion(text,at:app.now)}
    app.panel.orderFrontRegardless()
    func step() {
        while let event=NSApp.nextEvent(matching:.any,until:Date(),inMode:.default,dequeue:true) {NSApp.sendEvent(event)}
        app.tick(); NSApp.updateWindows(); app.art.needsDisplay=true; app.panel.displayIfNeeded()
        RunLoop.main.run(until:Date().addingTimeInterval(0.015))
    }
    func touch(_ type:NSEvent.EventType,_ point:CGPoint) {
        let e=NSEvent.mouseEvent(with:type,location:NSPoint(x:point.x,y:267-point.y),modifierFlags:[],timestamp:0,windowNumber:app.panel.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:1)!
        switch type {
        case .leftMouseDown: app.touch.mouseDown(with:e)
        case .leftMouseDragged: app.touch.mouseDragged(with:e)
        default: app.touch.mouseUp(with:e)
        }
    }
    let head=CGPoint(x:170,y:112)
    let warm=app.now; while app.now-warm<0.2 {step()}
    if !app.panel.occlusionState.contains(.visible),ProcessInfo.processInfo.environment["CAT_TEST_ALLOW_OCCLUDED_SKIP"] == "1" {
        print("SKIP stable receipt window: WindowServer reports no visible desktop surface; rerun on unlocked ordinary desktop")
        app.panel.orderOut(nil);return
    }
    app.toy.start(app.now); app.tick(); _=app.toyKey(124)
    touch(.leftMouseDown,head); step()
    precondition(growth.growth.points==2 && receipts.isEmpty && !app.art.text.contains("第 1 天"))
    touch(.leftMouseUp,head)
    let release=app.now; while receipts.isEmpty && app.now-release<1 {step()}
    precondition(receipts.count==1,"real released window must acknowledge completion")
    let (line,shown)=receipts[0]
    precondition(line.contains("第 1 天"))
    touch(.leftMouseDown,head)
    var lastVisible=shown
    while app.now-shown<3.5 {
        touch(.leftMouseDragged,CGPoint(x:head.x+sin((app.now-shown)*10)*7,y:head.y))
        step()
        let elapsed=app.now-shown
        if elapsed<2.8 {precondition(app.art.text==line,"held pet must never replace the visible completion")}
        if app.art.text==line {lastVisible=app.now}
    }
    precondition(app.touch.hasContact && app.art.text != line && receipts.count==1)
    precondition((2.85...3.15).contains(lastVisible-shown),"real receipt owns a three-second deadline during held input")
    touch(.leftMouseUp,head); step()
    for _ in 0..<4 {touch(.leftMouseDown,head);step();touch(.leftMouseUp,head);step();precondition(app.art.text != line)}
    growth.flushCompletionReceipt()
    let saved=try! store.load()!
    precondition(saved.points==2 && saved.completionShownDay==saved.day && receipts.count==1 && growth.window==nil)
    precondition(app.panel.childWindows?.isEmpty ?? true,"no probe remains during ordinary petting")
    print("PASS stable real 290pt window: held input cannot steal text, native receipt once, duration \(String(format:"%.2f",lastVisible-shown))s, continued/repeated pets do not replay, isolated persisted receipt, no growth panel or idle probe")
    app.panel.orderOut(nil)
}
