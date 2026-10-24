import AppKit

func runMenuTests(_ app:PetApp) {
    NSApp.setActivationPolicy(.regular);NSApp.finishLaunching()
    func check(_ ok:Bool,_ text:String) {if !ok {print("FAIL eye interaction: \(text)");exit(1)}}
    check(app.accessoryEyeGain==1.5,"preview must apply 33 percent enhancement over release62 gain 1.125")
    check(CatEyeAim(x:1,fixedApertureX:1,gain:app.accessoryEyeGain).gain==1.5,"renderer accepts selected gain")
    app.art=try! NativeCatView(resources:URL(fileURLWithPath:"src"))
    app.panel=PetPanel(contentRect:NSRect(x:60,y:200,width:290,height:267),styleMask:[.borderless],backing:.buffered,defer:false)
    let container=NSView(frame:NSRect(x:0,y:0,width:290,height:267))
    app.panel.contentView=container;app.art.frame=container.bounds;container.addSubview(app.art)
    app.touch=PetTouchView(frame:container.bounds);app.touch.owner=app;container.addSubview(app.touch);app.setupControls(in:container)
    #if CAT_EYE_INTERACTION
    check(app.selfTest && !app.isPlayPreview,"formal feature uses self-test isolation, no preview data")
    check(app.copyURL.path==ProcessInfo.processInfo.environment["CAT_TEST_COPY_FILE"],"formal feature must retain original personal-copy/self-test routing")
    let store=app.growthStore!
    var snapshot=CatGrowthSnapshot(unlockedRewards:[0,1,2],points:32,companionDays:16,completed:[.pet,.play],day:CatGrowth.dayKey(Date(),calendar:.current),ballSelected:true,decoration:nil)
    snapshot.decorations=[1,2];snapshot.completionShownDay=snapshot.day
    try! store.save(snapshot)
    let growth=CatGrowthController(owner:app,store:store);app.growthController=growth
    let file=URL(fileURLWithPath:ProcessInfo.processInfo.environment["CAT_TEST_GROWTH_FILE"]!)
    let saved=try! Data(contentsOf:file)
    check(!app.responds(to:NSSelectorFromString("useEnhancedEyeAmplitude")),"no preview amplitude selector")
    #else
    let growth=CatGrowthController(owner:app);app.growthController=growth;growth.prepareAccessoryDemo()
    #endif
    growth.accessory.frame=container.bounds;container.addSubview(growth.accessory)
    let prefs=UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?
    func advance(_ t:Double){Thread.sleep(forTimeInterval:t);app.tick()}
    func reset(){
        app.active=true;app.petVisible=true;app.paused=false;app.sleeping=false
        app.touch.cancelContact();app.finishToy();app.toy.finish(app.now,immediate:true)
        app.toyPupil=CatToyPupil();app.accessoryGaze.cancel();app.art.eyeAim = .neutral
        app.letterController?.window?.orderOut(nil);growth.window?.orderOut(nil)
        app.motion=CatMotion(now:app.now,seed:177,refinedTouch:true,headPetLeans:false)
        app.motion.nextBlink = .infinity;app.motion.nextGesture = .infinity
        app.art.update(CatPose());app.art.toyFrame=CatToyFrame();app.tick()
    }
    func click(_ reward:CatGrowthReward){
        let r=growth.accessory.interactionRect(for:reward),p=NSPoint(x:r.midX,y:267-r.midY)
        func e(_ t:NSEvent.EventType)->NSEvent {NSEvent.mouseEvent(with:t,location:p,modifierFlags:[],timestamp:app.now,windowNumber:app.panel.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:1)!}
        app.touch.mouseDown(with:e(.leftMouseDown));app.touch.mouseUp(with:e(.leftMouseUp))
    }
    for reward in [CatGrowthReward.flower,.fish] {
        reset();app.toy.start(app.now);app.tick();click(reward)
        check(app.accessoryGaze.isActive,"stationary newly opened ball must not block accessory glance")
        reset();app.motion.pet(app.now-1);app.tick();click(reward)
        check(app.accessoryGaze.isActive,"open-eyed stationary pet tail must not block accessory glance")
        reset();app.motion.pet(app.now-0.2);app.tick();click(reward)
        check(!app.accessoryGaze.isActive,"actual pet-eye response keeps priority")
        // Test held-contact priority directly, including after the 5s eye
        // limit has expired: no synthetic mouse-up should end that contact.
        reset();app.touch.region = .back;app.lookAtAccessory(reward)
        check(!app.accessoryGaze.isActive,"held body contact keeps priority even with open eyes")
        app.touch.region = .none
        reset();app.toy.start(app.now);app.toy.grab(app.now);app.tick();app.lookAtAccessory(reward)
        check(!app.accessoryGaze.isActive,"actual toy drag keeps priority")
        app.toy.move(to:CGPoint(x:0.61,y:0.355),at:app.now);app.toy.release(app.now);app.tick();app.lookAtAccessory(reward)
        check(!app.accessoryGaze.isActive,"fall/pending strike keeps priority")
    }
    for x in [0.55,0.67] {
        reset();let start=app.now-3.9
        app.toy.start(start);app.toy.grab(start+0.1)
        app.toy.move(to:CGPoint(x:x,y:CatToy.groundY(x)),at:start+0.2);app.toy.release(start+0.2)
        for step in 6...117 {_=app.toy.frame(start+Double(step)/30)}
        app.tick()
        check(app.toy.isEngaged(app.now),"exercise tail before original4.5s deadline")
        click(.fish);advance(0.05)
        check(app.accessoryGaze.isActive && app.art.eyeAim.x>0,"imperceptible settled toy residue yields and stays yielded")
        let eye=app.art.eyeAim.x;click(.fish)
        check(app.accessoryGaze.isActive && app.art.eyeAim.x>=eye,"repeated tail handoff never resets the glance")
        advance(0.3)
        check(app.accessoryGaze.isActive && app.art.eyeAim.x>0.9,"tail handoff survives subsequent ticks and repeated input")
    }
    for reward in [CatGrowthReward.flower,.fish] {
        reset();click(reward);advance(0.32)
        check(app.art.eyeAim.x>0.99 && app.art.eyeAim.gain==1.5,"real flower/fish click uses increased gaze")
        check(app.art.eyeVariation == .neutral,"glance does not widen pupil")
        check(growth.accessory.sway(for:reward).isActive,"original accessory sway remains")
        let eye=app.art.eyeAim.x;click(reward)
        check(abs(app.art.eyeAim.x-eye)<0.01,"repeat does not reset gaze")
        advance(0.7);let returning=app.art.eyeAim.x;click(reward)
        check(abs(app.art.eyeAim.x-returning)<0.02,"returning repeated click starts at current value")
        advance(1.5);check(app.art.eyeAim == .neutral,"natural finite recovery")
        click(reward);advance(0.1);app.pet();app.tick()
        check(app.art.eyeAim == .neutral && app.art.eyeVariation == .neutral,"pet takes over glance")
    }
    reset();app.toggleToy();check(app.toy.isOut && app.toyPupil.isActive,"toy appears immediately with cue")
    advance(0.8)
    check(abs(app.art.eyeVariation.pupilWidth-1.4)<1e-9 && app.art.eyeAim == .neutral,"actual opening reaches only pupil40")
    check(app.art.pose.lookX==0 && app.art.pose.head==0,"opening does not inject head motion")
    advance(1.3);check(app.art.eyeVariation == .neutral && !app.toyPupil.isActive,"pupil returns once")
    app.toggleToy();app.toggleToy();advance(0.8)
    check(app.toy.isOut && app.toyPupil.isActive && abs(app.art.eyeVariation.pupilWidth-1.4)<1e-9,"fast explicit hide/reopen has no pupil cooldown")
    for action in ["grab","head","back","stroke","menu","letter","growth","pause","hide","sleep","remove"] {
        reset();app.toggleToy();advance(0.8);check(app.toyPupil.isActive,"priority case begins with dilation")
        switch action {
        case "grab":app.beginToyContact()
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
        app.tick()
        check(!app.toyPupil.isActive && app.art.eyeVariation == .neutral,"cue yields without queue: \(action)")
        if action == "grab" {check(app.toy.dragging,"grab remains immediate")}
    }
    reset();app.pet();app.toggleToy();check(app.toy.isOut && !app.toyPupil.isActive,"busy head pet skips cue, not toy")
    advance(1);check(!app.toyPupil.isActive,"busy opening never plays later")
    reset();app.art.update(CatPose(eyes:0.5));app.toggleToy()
    check(app.toy.isOut && !app.toyPupil.isActive,"closed eye opening skipped")
    reset();click(.flower);advance(0.5);app.toggleToy();app.tick()
    check(app.toy.isOut && app.art.eyeAim == .neutral && app.art.eyeVariation == .neutral,"glance to toy never stacks cues")
    #if CAT_EYE_INTERACTION
    check(saved == (try! Data(contentsOf:file)),"eye interactions do not write growth/reward switches")
    let loaded=CatGrowthController(owner:app,store:store)
    check(loaded.growth.points==32 && loaded.ballSelected && loaded.decorations == [.flower,.fish],"formal controller reopens unchanged saved progress and switches")
    #else
    check(app.growthStore==nil && app.isPlayPreview,"no real growth store")
    #endif
    check(app.animationTimer==nil,"no added timer")
    check(!app.copyURL.path.contains("Application Support"),"preview uses bundled copy only")
    check(prefs==UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?,"formal preferences unchanged")
    app.panel.orderOut(nil)
    print("PASS real flower/fish enhanced gaze, continuous input, toy40 opening without cooldown, busy skip, immediate priorities, mutual exclusion and isolated storage")
}
