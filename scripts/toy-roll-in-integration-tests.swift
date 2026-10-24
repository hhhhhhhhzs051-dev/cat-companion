import AppKit

func runMenuTests(_ app:PetApp) {
    func check(_ ok:Bool,_ message:String) {if !ok {fputs("FAIL: \(message)\n",stderr);exit(1)}}
    let preferences=UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?
    let source=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("src")
    app.art=try! NativeCatView(resources:source)
    app.panel=PetPanel(contentRect:NSRect(x:0,y:0,width:290,height:267),styleMask:[.borderless],backing:.buffered,defer:false)
    let container=NSView(frame:NSRect(origin:.zero,size:app.panel.frame.size));app.panel.contentView=container
    app.art.frame=container.bounds;container.addSubview(app.art)
    app.touch=PetTouchView(frame:container.bounds);app.touch.owner=app;container.addSubview(app.touch)
    app.setupControls(in:container)
    app.active=true;app.motion=CatMotion(now:app.now,seed:12)
    app.copy=["pet":["嗯，再摸一下。"]]
    let growth=CatGrowthController(owner:app);app.growthController=growth
    #if CAT_PLAY_PREVIEW
    check(app.isPlayPreview && app.growthStore==nil,"Roll preview must not load a formal growth store")
    #else
    check(!app.isPlayPreview && app.selfTest && app.growthStore==nil,"Production-wiring test must use isolated self-test storage")
    #endif
    app.toy.start(app.now);app.tick();app.beginToyContact()
    app.moveToy(CGPoint(x:0.50*290,y:60+CatToy.groundY(0.50)*290))
    app.touch.playing=true
    let release=NSEvent.mouseEvent(with:.leftMouseUp,location:.zero,modifierFlags:[],timestamp:app.now,windowNumber:app.panel.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:0)!
    app.touch.mouseUp(with:release)
    check(growth.growth.points==1 && growth.growth.completed==[.play] && growth.window==nil,"One real release scores once, without opening growth")
    let start=app.now
    var rolledBeforePaw=false,sawPaw=false
    while app.now-start<1.8 {
        app.tick()
        let f=app.art.toyFrame
        if f.position.x>0.501 && f.paw==0 {rolledBeforePaw=true}
        if f.paw>0.01 {sawPaw=true;check(f.pawSide == -1,"Left ball uses the cat's right paw")}
        check(growth.growth.points==1,"Automatic surface roll/strike does not add growth")
        RunLoop.current.run(until:Date().addingTimeInterval(0.01))
    }
    check(rolledBeforePaw && sawPaw && app.toy.hits==1,"App's real handler/tick rolls then strikes once, including production wiring")
    app.beginToyContact();app.moveToy(CGPoint(x:0.72*290,y:60+CatToy.groundY(0.72)*290))
    app.touch.playing=true;app.touch.mouseUp(with:release)
    let again=app.now
    while app.now-again<0.10 {app.tick();RunLoop.current.run(until:Date().addingTimeInterval(0.01))}
    app.touchBack()
    let parked=app.art.toyFrame.position,stop=app.now
    while app.now-stop<1.0 {
        app.tick();check(app.art.toyFrame.position==parked && app.toy.hits==1,"Body pet parks instead of completing a stale assisted hit")
        RunLoop.current.run(until:Date().addingTimeInterval(0.01))
    }
    app.settingsReady=true;app.saveSettings()
    check(preferences == UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?,"Isolated integration never changes formal preferences")
    app.settingsReady=false;app.panel.orderOut(nil)
    print("PASS roll-in real handlers (preview=\(app.isPlayPreview)): release-to-roll-to-paw, one growth event, pet cancellation and isolated storage/preferences")
}
