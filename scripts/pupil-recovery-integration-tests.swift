import AppKit
func runMenuTests(_ app:PetApp) {
    NSApp.setActivationPolicy(.regular);NSApp.finishLaunching()
    func check(_ v:Bool,_ s:String){if !v {print("FAIL recovery integration: \(s)");exit(1)}}
    app.art=try! NativeCatView(resources:URL(fileURLWithPath:"src"))
    app.panel=PetPanel(contentRect:NSRect(x:60,y:200,width:290,height:267),styleMask:[.borderless],backing:.buffered,defer:false)
    let container=NSView(frame:NSRect(x:0,y:0,width:290,height:267))
    app.panel.contentView=container;app.art.frame=container.bounds;container.addSubview(app.art)
    app.touch=PetTouchView(frame:container.bounds);app.touch.owner=app;container.addSubview(app.touch);app.setupControls(in:container)
    #if CAT_PUPIL_RECOVERY
    check(app.selfTest && !app.isPlayPreview,"formal feature never enables simulated preview mode")
    check(app.copyURL.path==ProcessInfo.processInfo.environment["CAT_TEST_COPY_FILE"],"explicit self-test copy route")
    let store=app.growthStore!
    var snapshot=CatGrowthSnapshot(unlockedRewards:[0,1,2],points:32,companionDays:16,completed:[.pet,.play],day:CatGrowth.dayKey(Date(),calendar:.current),ballSelected:true,decoration:nil)
    snapshot.decorations=[1,2];snapshot.completionShownDay=snapshot.day
    try! store.save(snapshot)
    app.growthController=CatGrowthController(owner:app,store:store)
    let saved=try! Data(contentsOf:store.url)
    #else
    check(app.isPlayPreview && app.growthStore == nil,"preview cannot access real growth store")
    check(!app.copyURL.path.contains("Application Support/local.catcompanion.opensource"),"preview cannot load real copy")
    #endif
    let prefs=UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?
    func reset(){
        app.active=true;app.petVisible=true;app.paused=false;app.sleeping=false
        app.touch.cancelContact();app.toy.finish(app.now,immediate:true);app.toyPupil=CatToyPupil()
        app.accessoryGaze.cancel();app.art.eyeAim = .neutral;app.art.eyeVariation = .neutral
        app.motion=CatMotion(now:app.now,seed:177,refinedTouch:true,headPetLeans:false)
        app.motion.nextBlink = .infinity;app.motion.nextGesture = .infinity
        app.art.update(CatPose());app.art.toyFrame=CatToyFrame();app.tick()
    }
    func advance(_ t:Double){Thread.sleep(forTimeInterval:t);app.tick()}
    func event(_ type:NSEvent.EventType,_ point:CGPoint)->NSEvent {
        NSEvent.mouseEvent(with:type,location:app.art.convert(point,to:nil),modifierFlags:[],timestamp:app.now,windowNumber:app.panel.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:1)!
    }
    func ballPoint()->CGPoint {CGPoint(x:app.art.toyFrame.position.x*290,y:60+app.art.toyFrame.position.y*290)}
    func grab(){app.touch.mouseDown(with:event(.leftMouseDown,ballPoint()))}
    func release(){app.touch.mouseUp(with:event(.leftMouseUp,ballPoint()))}
    func peak(){reset();app.toggleToy();advance(0.8);check(app.art.eyeVariation.pupilWidth==1.5,"real takeout peak")}
    func finishRecovery(_ label:String){
        var prior=app.art.eyeVariation.pupilWidth
        for _ in 0..<30 {
            advance(1.0/30)
            let width=app.art.eyeVariation.pupilWidth
            check(width<=prior+1e-8 && prior-width<0.08,"\(label): bounded monotone recovery at normal30Hz")
            prior=width
        }
        check(!app.toyPupil.isActive && app.art.eyeVariation == .neutral,"\(label): no persistent tail or replay")
    }
    peak();app.motion.nextBlink=app.now;advance(0.02)
    check(app.art.pose.eyes>0 && app.art.eyeVariation.pupilWidth>1.49,"blink starts without snapping pupil")
    finishRecovery("blink")
    peak();app.pet()
    check(app.motion.petEnd>app.now && app.art.eyeVariation.pupilWidth>1.49,"head responds immediately, pupil stays continuous")
    advance(0.08);check(app.art.pose.eyes>0.9,"accepted head eye response starts on time")
    finishRecovery("head")
    peak();app.touchBack();app.stroke(.back)
    check(app.art.eyeVariation.pupilWidth>1.49,"body contact does not reset pupil")
    for _ in 0..<30 {app.stroke(.back);advance(0.035)}
    check(!app.toyPupil.isActive,"repeated strokes never extend recovery")
    check(app.art.pose.eyes>0.9,"body hold unchanged while pupil settles")
    app.touch.cancelContact();app.motion.releaseContactEyes(app.now)
    peak();grab();app.moveToy(CGPoint(x:0.61*290,y:60+CatToy.groundY(0.61)*290));advance(0.8)
    release();var sawPaw=false,prior=app.art.eyeVariation.pupilWidth
    for _ in 0..<8 {
        advance(0.02)
        if app.art.toyFrame.paw>0 {sawPaw=true}
        let width=app.art.eyeVariation.pupilWidth
        check(prior-width<0.05,"actual paw takeover does not snap pupil");prior=width
    }
    check(sawPaw && app.art.eyeVariation.pupilWidth>1.3,"paw starts before pupil has finished recovering")
    grab();check(app.toy.dragging,"regrab is immediate during paw retraction")
    finishRecovery("paw and busy regrab")
    grab();advance(0.8);check(app.art.eyeVariation.pupilWidth==1.5,"later eligible grab still triggers")
    release()
    peak();NotificationCenter.default.post(name:NSMenu.didBeginTrackingNotification,object:NSMenu())
    check(app.art.eyeVariation.pupilWidth>1.49,"menu event does not snap")
    finishRecovery("menu")
    peak()
    // This fixture drives most events without the app run loop. Present the
    // already-peaked image before measuring menu tracking, as in a real user
    // interaction; do not count first-window/CI compilation as an eye jump.
    app.panel.displayIfNeeded();app.art.displayIfNeeded()
    let heldPose=app.art.pose
    NotificationCenter.default.post(name:NSMenu.didBeginTrackingNotification,object:NSMenu())
    let menuStart=app.now
    var previous=app.art.eyeVariation.pupilWidth,sawIntermediate=false,lastMenuSample=app.now
    while app.now-menuStart<1.05 {
        _=RunLoop.main.run(mode:.eventTracking,before:Date().addingTimeInterval(0.035))
        let width=app.art.eyeVariation.pupilWidth
        check(previous-width<0.08 && width<=previous+1e-8,"application menu run-loop recovery continuity: previous=\(previous), width=\(width), dt=\(app.now-lastMenuSample), elapsed=\(app.now-menuStart)")
        if width>1.1 && width<1.4 {sawIntermediate=true}
        check(app.art.pose==heldPose,"application menu recovery must not advance other motions")
        previous=width;lastMenuSample=app.now
    }
    check(sawIntermediate && !app.toyPupil.isActive && previous==1,"application menu completes recovery without default ticks")
    peak();app.finishToy();app.tick()
    check(app.art.eyeVariation.pupilWidth>1.49,"put-away preserves visible eye exit")
    finishRecovery("put-away")
    for reason in ["pause","hidden","sleep","inactive"] {
        peak()
        switch reason {case "pause":app.paused=true;case "hidden":app.petVisible=false;case "sleep":app.sleeping=true;default:app.active=false}
        app.tick()
        check(!app.toyPupil.isActive && app.art.eyeVariation == .neutral,"\(reason): immediate safe cleanup")
        app.active=true;app.paused=false;app.petVisible=true;app.sleeping=false;app.tick()
        check(app.art.eyeVariation == .neutral,"\(reason): no replay")
    }
    #if CAT_PUPIL_RECOVERY
    check(saved == (try! Data(contentsOf:store.url)),"completed progress, rewards and independent switches never overwritten")
    let reopened=CatGrowthController(owner:app,store:store)
    check(reopened.growth.points==32 && reopened.growth.companionDays==16 && reopened.ballSelected && reopened.decorations == [.flower,.fish],"formal storage reopens all retained state")
    print("PASS recovery release isolated save reopening and retained growth/rewards/flower/fish")
    #endif
    check(prefs == UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?,"formal preferences untouched")
    print("PASS actual blink/head/body/paw/regrab/menu/putaway recovery; no delayed cat action; isolated storage and lifecycle")
    exit(0)
}
