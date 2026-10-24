import AppKit
func runMenuTests(_ app:PetApp) {
    NSApp.setActivationPolicy(.regular);NSApp.finishLaunching()
    func check(_ ok:Bool,_ s:String){if !ok {print("FAIL handoff: \(s)");exit(1)}}
    app.art=try! NativeCatView(resources:URL(fileURLWithPath:"src"))
    app.panel=PetPanel(contentRect:NSRect(x:60,y:200,width:290,height:267),styleMask:[.borderless],backing:.buffered,defer:false)
    let container=NSView(frame:app.panel.contentView!.bounds);app.panel.contentView=container
    app.art.frame=container.bounds;container.addSubview(app.art)
    app.touch=PetTouchView(frame:container.bounds);app.touch.owner=app;container.addSubview(app.touch);app.setupControls(in:container)
    #if CAT_EYE_HANDOFF
    check(app.selfTest && !app.isPlayPreview,"formal flags never enable preview storage")
    check(app.copyURL.path==ProcessInfo.processInfo.environment["CAT_TEST_COPY_FILE"],"explicit isolated copy route")
    let store=app.growthStore!
    check(store.url.path==ProcessInfo.processInfo.environment["CAT_TEST_GROWTH_FILE"],"explicit isolated growth route")
    var fixture=CatGrowthSnapshot(unlockedRewards:[0,1,2],points:32,companionDays:16,completed:[.pet,.play],day:CatGrowth.dayKey(Date(),calendar:.current),ballSelected:true,decoration:nil)
    fixture.decorations=[1,2];fixture.completionShownDay=fixture.day
    try! store.save(fixture)
    let saved=try! Data(contentsOf:store.url)
    let growth=CatGrowthController(owner:app,store:store)
    #else
    let growth=CatGrowthController(owner:app);growth.prepareAccessoryDemo()
    check(app.isPlayPreview && app.growthStore == nil,"in-memory preview only")
    #endif
    app.growthController=growth
    growth.accessory.frame=container.bounds;container.addSubview(growth.accessory)
    let prefs=UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?
    func advance(_ t:Double){Thread.sleep(forTimeInterval:t);app.tick()}
    func reset(){
        app.active=true;app.petVisible=true;app.paused=false;app.sleeping=false;app.touch.cancelContact()
        app.toy.finish(app.now,immediate:true);app.toyPupil=CatToyPupil();app.accessoryGaze.cancel()
        app.art.eyeAim = .neutral;app.art.eyeVariation = .neutral
        app.motion=CatMotion(now:app.now,seed:177,refinedTouch:true,headPetLeans:false)
        app.motion.nextBlink = .infinity;app.motion.nextGesture = .infinity;app.art.update(CatPose());app.tick()
    }
    func click(_ reward:CatGrowthReward){
        let r=growth.accessory.interactionRect(for:reward),p=NSPoint(x:r.midX,y:267-r.midY)
        func e(_ t:NSEvent.EventType)->NSEvent {NSEvent.mouseEvent(with:t,location:p,modifierFlags:[],timestamp:app.now,windowNumber:app.panel.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:1)!}
        app.touch.mouseDown(with:e(.leftMouseDown));app.touch.mouseUp(with:e(.leftMouseUp))
    }
    for reward in [CatGrowthReward.flower,.fish] {
        reset();app.toggleToy();advance(0.8)
        check(app.art.eyeVariation.pupilWidth==1.5,"real opening peak")
        click(reward);advance(0.06)
        check(app.art.eyeAim.x>0 && app.art.eyeVariation.pupilWidth>1.45,"accessory begins while current pupil smoothly returns, not hard cancel")
        var previous=app.art.eyeVariation.pupilWidth
        for i in 0..<30 {
            if i%3==0 {click(reward)}
            advance(1.0/30)
            let w=app.art.eyeVariation.pupilWidth
            check(w<=previous+0.0001 && previous-w<0.09,"repeat clicks never reset or snap recovery");previous=w
        }
        check(app.art.eyeVariation == .neutral && !app.toyPupil.isActive,"finite recovery despite repeat gaze")
        advance(1.3);check(app.art.eyeAim == .neutral,"finite gaze after last click")
        reset();app.toggleToy();advance(0.8);app.finishToy();advance(0.3)
        let before=app.art.eyeVariation.pupilWidth;click(reward);advance(0.03)
        check(app.art.eyeVariation.pupilWidth>1 && before-app.art.eyeVariation.pupilWidth<0.08,"putaway recovery also hands off without snap")
        app.pet();advance(0.09)
        check(app.art.pose.eyes>0.9 && app.art.eyeAim == .neutral,"head response takes priority immediately")
        advance(1.0);check(app.art.eyeVariation == .neutral,"head interruption settles")
        reset();app.toggleToy();advance(0.8);app.toy.grab(app.now);app.touch.playing=true
        app.lookAtAccessory(reward);app.tick()
        check(!app.accessoryGaze.isActive,"actual ball drag blocks gaze")
        app.touch.cancelContact()
        reset();app.toggleToy();advance(0.8);click(reward);advance(0.04);app.paused=true;app.tick()
        check(app.art.eyeAim == .neutral && app.art.eyeVariation == .neutral,"rest cancels both without replay")
    }
    #if CAT_EYE_HANDOFF
    check(saved == (try! Data(contentsOf:store.url)),"existing progress and switches not overwritten")
    let reopened=CatGrowthController(owner:app,store:store)
    check(reopened.growth.points==32 && reopened.growth.companionDays==16 && reopened.ballSelected && reopened.decorations == [.flower,.fish],"formal save reopens with all earned state")
    #endif
    check(prefs==UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?,"formal preferences untouched")
    print("PASS actual flower/fish handoff, finite repeated input, putaway tail, pet/drag priorities and rest; no real storage")
    exit(0)
}
