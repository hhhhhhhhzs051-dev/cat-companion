import AppKit
func runMenuTests(_ app:PetApp) {
    NSApp.setActivationPolicy(.regular);NSApp.finishLaunching()
    func check(_ v:Bool,_ s:String){if !v {print("FAIL pupil play integration: \(s)");exit(1)}}
    app.art=try! NativeCatView(resources:URL(fileURLWithPath:"src"))
    app.panel=PetPanel(contentRect:NSRect(x:60,y:200,width:290,height:267),styleMask:[.borderless],backing:.buffered,defer:false)
    let container=NSView(frame:NSRect(x:0,y:0,width:290,height:267))
    app.panel.contentView=container;app.art.frame=container.bounds;container.addSubview(app.art)
    app.touch=PetTouchView(frame:container.bounds);app.touch.owner=app;container.addSubview(app.touch);app.setupControls(in:container)
    #if CAT_PUPIL_PLAY
    check(app.selfTest && !app.isPlayPreview,"formal feature does not enable simulated preview storage")
    check(app.copyURL.path==ProcessInfo.processInfo.environment["CAT_TEST_COPY_FILE"],"formal self-test retains explicit copy route")
    let store=app.growthStore!
    var snapshot=CatGrowthSnapshot(unlockedRewards:[0,1,2],points:32,companionDays:16,completed:[.pet,.play],day:CatGrowth.dayKey(Date(),calendar:.current),ballSelected:true,decoration:nil)
    snapshot.decorations=[1,2];snapshot.completionShownDay=snapshot.day
    try! store.save(snapshot)
    let growth=CatGrowthController(owner:app,store:store);app.growthController=growth
    let file=URL(fileURLWithPath:ProcessInfo.processInfo.environment["CAT_TEST_GROWTH_FILE"]!)
    let saved=try! Data(contentsOf:file)
    #else
    let growth=CatGrowthController(owner:app);app.growthController=growth;growth.prepareAccessoryDemo()
    #endif
    growth.accessory.frame=container.bounds;container.addSubview(growth.accessory)
    let prefs=UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?
    func reset(){
        app.active=true;app.petVisible=true;app.paused=false;app.sleeping=false
        app.touch.cancelContact();app.finishToy();app.toy.finish(app.now,immediate:true)
        app.toyPupil=CatToyPupil();app.accessoryGaze.cancel();app.art.eyeAim = .neutral
        app.letterController?.window?.orderOut(nil);growth.window?.orderOut(nil)
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
    reset();app.toggleToy();advance(0.8)
    check(app.toy.isOut && app.art.eyeVariation.pupilWidth==1.5,"actual take-out reaches50 percent")
    advance(0.8);check(app.art.eyeVariation.pupilWidth==1.5,"menu-free hold is long enough to observe")
    advance(1.2);check(app.art.eyeVariation == .neutral && !app.toyPupil.isActive,"no loop")
    grab();advance(0.8)
    check(app.touch.playing && app.toy.dragging && app.art.eyeVariation.pupilWidth==1.5,"real ball mouse-down triggers during held contact")
    for i in 0..<25 {
        app.touch.mouseDragged(with:event(.leftMouseDragged,CGPoint(x:160+i,y:195)))
        advance(0.09)
    }
    check(app.art.eyeVariation == .neutral && !app.toyPupil.isActive,"mousemove never restarts or perpetually extends dilation")
    app.touch.mouseUp(with:event(.leftMouseUp,ballPoint()));app.tick()
    grab();advance(0.35);let halfway=app.art.eyeVariation.pupilWidth
    check(halfway>1 && halfway<1.5,"same-session regrab triggers, without cooldown")
    app.touch.mouseUp(with:event(.leftMouseUp,ballPoint()));grab();app.tick()
    check(app.art.eyeVariation.pupilWidth>=halfway-0.01,"release/regrab cannot abruptly reset pupil")
    advance(0.8);check(app.art.eyeVariation.pupilWidth==1.5,"regrab survives toy head and ear response")
    app.touch.mouseUp(with:event(.leftMouseUp,ballPoint()));advance(3)
    check(!app.toyPupil.isActive,"stop playing remains quiet")
    for action in ["head","back","stroke","menu","letter","growth","pause","hide","sleep","remove"] {
        reset();app.toggleToy();advance(0.8)
        switch action {
        case "head":app.pet()
        case "back":app.touchBack()
        case "stroke":app.stroke(.back)
        case "menu":NotificationCenter.default.post(name:NSMenu.didBeginTrackingNotification,object:NSMenu())
        case "letter":app.showLetter()
        case "growth":app.showGrowth()
        case "pause":app.paused=true
        case "hide":app.petVisible=false
        case "sleep":app.sleeping=true
        default:app.finishToy()
        }
        app.tick();check(!app.toyPupil.isActive && app.art.eyeVariation == .neutral,"priority cancellation: \(action)")
    }
    reset();app.pet();app.toggleToy();grab();app.tick()
    check(app.toy.isOut && !app.toyPupil.isActive,"real pet priority skips cue, not toy")
    advance(1);check(!app.toyPupil.isActive,"busy cue is not queued")
    reset();app.toggleToy();grab();app.moveToy(CGPoint(x:0.61*290,y:60+CatToy.groundY(0.61)*290))
    app.touch.mouseUp(with:event(.leftMouseUp,ballPoint()))
    var sawPaw=false
    for _ in 0..<35 {advance(0.03);if app.art.toyFrame.paw>0 {sawPaw=true;check(app.art.eyeVariation == .neutral,"actual strike keeps priority")}}
    check(sawPaw,"exercise actual accepted strike")
    reset();app.toggleToy();grab();app.moveToy(CGPoint(x:0.61*290,y:60+CatToy.groundY(0.61)*290))
    app.touch.mouseUp(with:event(.leftMouseUp,ballPoint()))
    for _ in 0..<30 {advance(0.02);if app.art.toyFrame.paw>0.05 {break}}
    check(app.art.toyFrame.paw>0.05,"exercise regrab during visible strike")
    grab();app.tick()
    check(app.toy.dragging && app.art.toyFrame.paw>0 && !app.toyPupil.isActive,"regrab keeps visible paw-retraction priority")
    advance(0.5);check(!app.toyPupil.isActive,"skipped paw-retraction cue never queues")
    reset();app.lookAtAccessory(.fish);advance(0.3)
    check(app.art.eyeAim.x>0.9 && app.art.eyeVariation == .neutral,"accessory gaze unchanged and separate")
    app.toy.start(app.now);app.tick();grab();advance(0.8)
    check(app.art.eyeAim == .neutral && app.art.eyeVariation.pupilWidth==1.5,"grab owns pupil, no overlapping accessory eyes")
    #if CAT_PUPIL_PLAY
    check(saved == (try! Data(contentsOf:file)),"interactions never overwrite completed growth/rewards/switches")
    let reopened=CatGrowthController(owner:app,store:store)
    check(reopened.growth.points==32 && reopened.ballSelected && reopened.decorations == [.flower,.fish],"reopened growth and independent flower/fish switches preserved")
    #else
    check(app.growthStore==nil && app.isPlayPreview && !app.copyURL.path.contains("Application Support"),"isolated storage")
    #endif
    check(app.animationTimer==nil,"no additional timer")
    check(prefs==UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?,"real preferences unchanged")
    app.panel.orderOut(nil)
    print("PASS real take-out/grab/drag/regrab, no per-move restart, pet/paw/lifecycle priorities, gaze exclusion and isolated saves")
}
