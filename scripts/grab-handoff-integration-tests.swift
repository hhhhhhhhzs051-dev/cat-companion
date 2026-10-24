import AppKit

func runMenuTests(_ app:PetApp) {
    NSApp.setActivationPolicy(.regular);NSApp.finishLaunching()
    func check(_ ok:Bool,_ message:String) {if !ok {print("FAIL grab handoff: \(message)");exit(1)}}
    app.art=try! NativeCatView(resources:URL(fileURLWithPath:"src"))
    app.panel=PetPanel(contentRect:NSRect(x:60,y:200,width:290,height:267),styleMask:[.borderless],backing:.buffered,defer:false)
    let container=NSView(frame:app.panel.contentView!.bounds);app.panel.contentView=container
    app.art.frame=container.bounds;container.addSubview(app.art)
    app.touch=PetTouchView(frame:container.bounds);app.touch.owner=app;container.addSubview(app.touch)
    #if CAT_GRAB_HANDOFF
    check(app.selfTest && !app.isPlayPreview,"formal configuration never enables preview storage")
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
    check(app.isPlayPreview && app.growthStore == nil,"only in-memory preview data")
    #endif
    app.growthController=growth
    growth.accessory.frame=container.bounds;container.addSubview(growth.accessory)
    let prefs=UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?
    func advance(_ seconds:Double) {Thread.sleep(forTimeInterval:seconds);app.tick()}
    func event(_ type:NSEvent.EventType,_ p:CGPoint)->NSEvent {
        NSEvent.mouseEvent(with:type,location:app.art.convert(p,to:nil),modifierFlags:[],timestamp:app.now,windowNumber:app.panel.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:1)!
    }
    func point()->CGPoint {CGPoint(x:app.art.toyFrame.position.x*290,y:60+app.art.toyFrame.position.y*290)}
    func reset() {
        app.finishToy();app.touch.cancelContact();app.active=true;app.petVisible=true;app.paused=false;app.sleeping=false
        app.toy=CatToy();app.toyPupil=CatToyPupil();app.accessoryGaze.cancel()
        app.art.eyeAim = .neutral;app.art.eyeVariation = .neutral
        app.motion=CatMotion(now:app.now,seed:177,refinedTouch:true,headPetLeans:false)
        app.motion.nextBlink = .infinity;app.motion.nextGesture = .infinity
        app.art.update(CatPose());app.toy.start(app.now-5);app.tick()
    }
    reset();app.lookAtAccessory(.fish);advance(0.25)
    let before=app.art.pose,aim=app.art.eyeAim
    check(before.lookX>0.27 && before.rightEar>0.17 && aim.x>0.99,"exercise actual peak with settled ball")
    app.touch.mouseDown(with:event(.leftMouseDown,point()))
    check(app.art.pose==before && app.art.eyeAim==aim,"mouse-down itself leaves the displayed frame intact before tick")
    app.tick()
    check(app.touch.playing && app.toy.dragging,"real mouse-down grabs immediately")
    check(abs(app.art.pose.lookX-before.lookX)<0.01 && abs(app.art.pose.rightEar-before.rightEar)<0.01 && abs(app.art.eyeAim.x-aim.x)<0.03,
          "grab preserves last displayed head, ear and eye instead of snapping neutral")
    check(!app.accessoryGaze.isActive,"old accessory action gives up ownership immediately")
    advance(0.8)
    check(app.art.eyeAim == .neutral && app.art.eyeVariation.pupilWidth==1.5,"original grab dilation reaches50 percent on time")
    advance(2)
    check(app.art.eyeVariation == .neutral,"original2.7s cue ends without looping")
    #if CAT_GRAB_HANDOFF_PREVIEW || CAT_GRAB_HANDOFF
    reset();app.lookAtAccessory(.fish);advance(0.25)
    app.touch.mouseDown(with:event(.leftMouseDown,point()))
    NotificationCenter.default.post(name:NSMenu.didBeginTrackingNotification,object:NSMenu())
    check(!app.grabHandoff.isActive && app.art.eyeAim == .neutral && app.art.pose.lookX==0 && app.art.pose.rightEar==0,
          "menu before first grab tick restores original base immediately")
    for reward in [CatGrowthReward.flower,.fish] {
        for phase in [0.06,0.25,0.72] {
            for x in [0.49,0.73] {
                reset();app.lookAtAccessory(reward);advance(phase)
                let visible=app.art.pose,eye=app.art.eyeAim.x
                app.touch.mouseDown(with:event(.leftMouseDown,point()));app.tick()
                check(abs(app.art.pose.lookX-visible.lookX)<0.015 && abs(app.art.pose.rightEar-visible.rightEar)<0.015 && abs(app.art.eyeAim.x-eye)<0.045,
                      "rise/peak/return preserves displayed contribution for either accessory")
                let target=CGPoint(x:x*290,y:60+CatToy.groundY(x)*290)
                app.touch.mouseDragged(with:event(.leftMouseDragged,target))
                check(abs(app.art.toyFrame.position.x-x)<1e-9,"dragged ball moves immediately while gaze returns")
                var prior=app.art.eyeAim.x
                for _ in 0..<9 {
                    advance(1.0/30)
                    check(app.art.eyeAim.x<=prior+1e-9 && prior-app.art.eyeAim.x<0.23,"finite monotone eye return, no reset or one-frame cancellation")
                    prior=app.art.eyeAim.x
                }
                check(!app.grabHandoff.isActive && app.art.eyeAim == .neutral,"handoff releases fully to unchanged toy gaze")
            }
        }
    }
    // Regrab renews only the accepted pupil cue, never the visual remainder.
    reset();app.lookAtAccessory(.fish);advance(0.25)
    app.touch.mouseDown(with:event(.leftMouseDown,point()));advance(0.10)
    let firstRemainder=app.art.eyeAim.x
    app.touch.mouseUp(with:event(.leftMouseUp,point()))
    app.touch.mouseDown(with:event(.leftMouseDown,point()));app.tick()
    check(app.art.eyeAim.x<=firstRemainder+0.01,"regrab cannot rewind the handoff")
    advance(0.17)
    check(!app.grabHandoff.isActive && app.art.eyeAim == .neutral,"regrab cannot extend the handoff deadline")
    advance(0.6);check(app.art.eyeVariation.pupilWidth==1.5,"regrab keeps original pupil cue")
    // A returning old pupil can hand to a glance and then a new explicit grab.
    reset();_=app.toyPupil.grab(at:app.now-0.8,allowed:true);app.tick()
    check(app.art.eyeVariation.pupilWidth==1.5,"mixed case starts at accepted pupil peak")
    app.lookAtAccessory(.flower);advance(0.12)
    let width=app.art.eyeVariation.pupilWidth
    check(width>1 && app.art.eyeAim.x>0,"mixed recovery and glance genuinely coexist")
    app.touch.mouseDown(with:event(.leftMouseDown,point()));app.tick()
    check(abs(app.art.eyeVariation.pupilWidth-width)<0.015,"new grab retains current pupil width")
    advance(0.72);check(app.art.eyeVariation.pupilWidth==1.5,"new explicit grab reaches existing50 percent peak on time")
    // Natural blinking keeps the head remainder but must not bypass pupil gating.
    reset();app.lookAtAccessory(.fish);advance(0.25)
    app.touch.mouseDown(with:event(.leftMouseDown,point()));advance(0.05)
    app.motion.nextBlink=app.now;advance(0.03)
    check(app.art.pose.eyes>0 && app.grabHandoff.isActive,"natural blink does not snap head/ear return")
    let blinkingWidth=app.art.eyeVariation.pupilWidth
    advance(0.8);check(app.art.eyeVariation == .neutral && blinkingWidth<1.1,"blink still interrupts pupil without queued widening")
    // Actual pet/paw/window/lifecycle actions keep priority, with no deferred replay.
    for cancel in ["head","back","stroke","paw","menu","letter","growth","pause","hide","sleep","remove"] {
        reset();app.letterController?.window?.orderOut(nil);growth.window?.orderOut(nil)
        app.lookAtAccessory(.fish);advance(0.25)
        app.touch.mouseDown(with:event(.leftMouseDown,point()));advance(0.04)
        check(app.grabHandoff.isActive,"exercise cancellation during visible remainder")
        switch cancel {
        case "head":app.pet()
        case "back":app.touchBack()
        case "stroke":app.stroke(.back)
        case "paw":
            app.moveToy(CGPoint(x:0.61*290,y:60+CatToy.groundY(0.61)*290))
            app.touch.mouseUp(with:event(.leftMouseUp,point()));advance(0.12)
            // The first eligible tick commits hitAt; its pose is still the
            // accepted zero-strength start. The following frame extends it.
            check(app.toy.hits==1 && app.grabHandoff.isActive,"strike commits before handoff deadline")
            advance(1.0/30)
            check(app.art.toyFrame.paw>0,"accepted paw starts without waiting for handoff")
        case "menu":
            let baseLook=app.art.toyFrame.look
            NotificationCenter.default.post(name:NSMenu.didBeginTrackingNotification,object:NSMenu())
            check(app.art.eyeAim == .neutral && abs(app.art.pose.lookX-baseLook)<1e-9,"menu restores underlying toy pose without needing a tick")
        case "letter":app.showLetter()
        case "growth":app.showGrowth()
        case "pause":app.paused=true
        case "hide":app.petVisible=false
        case "sleep":app.sleeping=true
        default:app.finishToy()
        }
        app.tick();check(!app.grabHandoff.isActive && app.art.eyeAim == .neutral,"priority cancellation: \(cancel)")
        app.active=true;app.paused=false;app.petVisible=true;app.sleeping=false
        app.touch.cancelContact();app.letterController?.window?.orderOut(nil);growth.window?.orderOut(nil)
        advance(0.3);check(!app.grabHandoff.isActive,"cancelled remainder never replays")
    }
    check(app.animationTimer==nil,"handoff adds no timer")
    #endif
    #if CAT_GRAB_HANDOFF
    check(saved == (try! Data(contentsOf:store.url)),"existing progress and switches not overwritten")
    let reopened=CatGrowthController(owner:app,store:store)
    check(reopened.growth.points==32 && reopened.growth.companionDays==16 && reopened.ballSelected && reopened.decorations == [.flower,.fish],"formal save reopens with earned state and both switches")
    #endif
    check(prefs==UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?,"real preferences unchanged")
    print("PASS real rise/peak/return grab continuity, either ball direction, regrab deadline, blink/paw/lifecycle priorities, mixed pupil recovery and original pupil timing")
}
