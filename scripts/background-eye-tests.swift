import AppKit
func runMenuTests(_ app:PetApp) {
    NSApp.setActivationPolicy(.regular);NSApp.finishLaunching()
    var count=0
    func check(_ ok:Bool,_ text:String) {guard ok else {print("FAIL background eyes: \(text)");exit(1)};count+=1}
    app.art=try! NativeCatView(resources:URL(fileURLWithPath:"src"))
    app.panel=PetPanel(contentRect:NSRect(x:60,y:200,width:290,height:267),styleMask:[.borderless],backing:.buffered,defer:false)
    let container=NSView(frame:NSRect(x:0,y:0,width:290,height:267));app.panel.contentView=container
    app.art.frame=container.bounds;container.addSubview(app.art)
    app.touch=PetTouchView(frame:container.bounds);app.touch.owner=app;container.addSubview(app.touch)
    #if CAT_GRAB_HANDOFF
    check(app.selfTest && !app.isPlayPreview,"formal feature branches use explicit self-test isolation")
    check(app.copyURL.path==ProcessInfo.processInfo.environment["CAT_TEST_COPY_FILE"],"isolated formal copy route")
    let store=app.growthStore!
    check(store.url.path==ProcessInfo.processInfo.environment["CAT_TEST_GROWTH_FILE"],"isolated formal growth route")
    var fixture=CatGrowthSnapshot(unlockedRewards:[0,1,2],points:32,companionDays:16,completed:[.pet,.play],day:CatGrowth.dayKey(Date(),calendar:.current),ballSelected:false,decoration:nil)
    fixture.decorations=[1,2];fixture.completionShownDay=fixture.day
    try! store.save(fixture)
    let growth=CatGrowthController(owner:app,store:store)
    #else
    let growth=CatGrowthController(owner:app);growth.prepareAccessoryDemo()
    check(app.isPlayPreview && app.growthStore == nil,"isolated in-memory growth only")
    #endif
    app.growthController=growth
    growth.accessory.frame=container.bounds;container.addSubview(growth.accessory)
    let prefs=UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?
    func advance(_ t:Double){Thread.sleep(forTimeInterval:t);app.tick()}
    func reset() {
        app.letterController?.window?.orderOut(nil);growth.window?.orderOut(nil)
        app.touch.cancelContact();app.active=true;app.paused=false;app.sleeping=false;app.petVisible=true
        app.toy=CatToy(rollInEnabled:true);app.toyPupil=CatToyPupil();app.accessoryGaze.cancel();app.grabHandoff.cancel()
        app.art.eyeAim = .neutral;app.art.eyeVariation = .neutral
        app.motion=CatMotion(now:app.now,seed:177,refinedTouch:true,headPetLeans:false)
        app.motion.nextBlink = .infinity;app.motion.nextGesture = .infinity
        app.art.update(CatPose());app.tick()
    }
    func event(_ type:NSEvent.EventType,_ p:CGPoint)->NSEvent {
        NSEvent.mouseEvent(with:type,location:app.art.convert(p,to:nil),modifierFlags:[],timestamp:app.now,windowNumber:app.panel.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:1)!
    }
    func click(_ reward:CatGrowthReward) {
        let r=growth.accessory.interactionRect(for:reward),p=CGPoint(x:r.midX,y:r.midY)
        app.touch.mouseDown(with:event(.leftMouseDown,p));app.touch.mouseUp(with:event(.leftMouseUp,p))
    }
    func ball()->CGPoint {CGPoint(x:app.art.toyFrame.position.x*290,y:60+app.art.toyFrame.position.y*290)}
    func background(_ mode:String) {
        if mode != "letter" {app.showGrowth()}
        if mode != "growth" {app.showLetter()}
        NSApp.activate(ignoringOtherApps:true);app.panel.makeKeyAndOrderFront(nil)
        check((growth.window?.isVisible == true || app.letterController?.window?.isVisible == true),"panel is open, not silently closed")
        check(growth.window?.isKeyWindow != true && app.letterController?.window?.isKeyWindow != true,"panels are background")
    }
    for mode in ["growth","letter","both"] {
        for reward in [CatGrowthReward.flower,.fish] {
            reset();background(mode);click(reward)
            check(app.accessoryGaze.isActive,"\(mode) background must not reject explicit \(reward)")
            advance(0.25)
            check(app.art.pose.lookX>0.27 && app.art.eyeAim.x>0.99,"original gaze peak and timing")
            check(growth.accessory.sway(for:reward).isActive,"original accessory sway not suppressed by background letter")
            advance(1.0);check(!app.accessoryGaze.isActive && app.art.eyeAim == .neutral,"finite original return")
        }
        reset();background(mode);app.toggleToy();advance(0.8)
        check(app.art.eyeVariation.pupilWidth==1.5,"background toy opening reaches original50 percent")
        advance(2);check(app.art.eyeVariation == .neutral,"original2.7 second cue ends")
        app.touch.mouseDown(with:event(.leftMouseDown,ball()));advance(0.8)
        check(app.toy.dragging && app.art.eyeVariation.pupilWidth==1.5,"background explicit grab starts original cue immediately")
        advance(2);check(app.art.eyeVariation == .neutral,"grab does not loop")
        reset();background(mode);app.toy.start(app.now-5);app.tick();click(.fish);advance(0.25)
        let gaze=app.art.eyeAim.x,look=app.art.pose.lookX
        app.touch.mouseDown(with:event(.leftMouseDown,ball()));app.tick()
        check(app.grabHandoff.isActive && abs(app.art.eyeAim.x-gaze)<0.04 && abs(app.art.pose.lookX-look)<0.015,"background gaze-to-grab retains smooth remainder")
        advance(0.3);check(!app.grabHandoff.isActive,"0.24s handoff timing unchanged")
    }
    for priority in ["head","back","drag","paw","pause","hide","sleep"] {
        reset();background("both")
        switch priority {
        case "head":app.touch.region = .head;app.pet()
        case "back":app.touch.region = .back;app.touchBack()
        case "drag":app.toy.start(app.now);app.toy.grab(app.now)
        case "paw":
            app.toy.start(app.now);app.toy.grab(app.now);app.toy.move(to:CGPoint(x:0.61,y:CatToy.groundY(0.61)),at:app.now);app.toy.release(app.now)
            advance(0.12);advance(0.04);check(app.art.toyFrame.paw>0,"exercise actual paw phase")
        case "pause":app.paused=true
        case "hide":app.petVisible=false
        default:app.sleeping=true
        }
        app.lookAtAccessory(.flower);check(!app.accessoryGaze.isActive,"\(priority) still outranks accessory gaze")
        if ["head","back","paw"].contains(priority) {app.beginToyContact();app.tick();check(app.art.eyeVariation == .neutral,"\(priority) still blocks new widening")}
    }
    reset();background("both");click(.flower);advance(0.25);app.showGrowth();app.tick()
    check(!app.accessoryGaze.isActive && app.art.eyeAim == .neutral,"explicit opening of growth still cancels ongoing glance")
    reset();background("both");app.toggleToy();advance(0.8);app.showLetter();app.tick()
    check(app.art.eyeVariation.pupilWidth>1,"letter handoff retains existing smooth pupil exit")
    advance(0.85);check(app.art.eyeVariation == .neutral,"front letter ends cue without replay")
    check(prefs==UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?,"real preferences unchanged")
    print("PASS \(count) background-window interaction and priority checks")
}
