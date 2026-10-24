import AppKit

func runMenuTests(_ app: PetApp) {
    func check(_ result: Bool, _ message: String) { if !result { fputs("FAIL: \(message)\n",stderr); exit(1) } }
    let source = URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("src")
    app.art = try! NativeCatView(resources:source)
    app.panel = PetPanel(contentRect:NSRect(x:60,y:200,width:290,height:267),styleMask:[.borderless],backing:.buffered,defer:false)
    let container = NSView(frame:NSRect(origin:.zero,size:app.panel.frame.size)); app.panel.contentView = container
    app.art.frame = container.bounds; container.addSubview(app.art)
    app.touch = PetTouchView(frame:container.bounds); app.touch.owner = app; container.addSubview(app.touch)
    app.copy = ["pet":["原来的摸头短句。"]]
    func reset() -> CatGrowthController {
        app.touch.cancelContact(); app.active=true; app.paused=false; app.petVisible=true
        app.motion=CatMotion(now:app.now,seed:12); app.toy=CatToy(); app.playMood=CatPlayMood()
        let growth=CatGrowthController(owner:app); app.growthController=growth
        app.tick(); return growth
    }
    func event(_ type:NSEvent.EventType,_ point:CGPoint) -> NSEvent {
        NSEvent.mouseEvent(with:type,location:NSPoint(x:point.x,y:container.bounds.height-point.y),modifierFlags:[],timestamp:0,windowNumber:app.panel.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:1)!
    }
    func isCompletion() -> Bool { app.art.text.contains("第 1 天") }
    var growth=reset()
    app.pet(); check(!isCompletion() && growth.growth.points==1,"first goal keeps ordinary feedback, never daily completion")
    let originalPetEnd=app.motion.petEnd
    app.toy.start(app.now); app.tick()
    let p=app.art.toyCenter, q=CGPoint(x:p.x-20,y:p.y-8)
    app.touch.mouseDown(with:event(.leftMouseDown,p)); app.touch.mouseDragged(with:event(.leftMouseDragged,q))
    app.playMood=CatPlayMood(); app.playMood.beginSession()
    app.playMood.react(at:app.now,sample:0,allowed:true)
    app.tick(); check(!isCompletion() && growth.growth.points==1,"held ball drag cannot complete or speak early")
    app.touch.mouseUp(with:event(.leftMouseUp,q)); app.tick()
    check(isCompletion(),"second goal must speak on first released frame, not after ball attention or ordinary speech")
    check(growth.window==nil && growth.growth.points==2 && growth.completionFeedback.shownDay==0,"no panel needed; assigning text is not a delivery receipt")
    check(app.toy.isEngaged(app.now) && !app.petPhrase.isEmpty && app.motion.petEnd==originalPetEnd,"completion wins text priority without ending toy attention or changing motion clock")
    let time=app.now, referenceMotion=app.motion, referenceToy=app.toy
    _=app.completionText("咦？",at:time)
    var a=referenceMotion, b=app.motion, c=referenceToy, d=app.toy
    for offset in [0.0,0.12,0.7,1.4,4.6] {
        check(a.frame(time+offset,reduced:false,paused:false)==b.frame(time+offset,reduced:false,paused:false),"text selection cannot mutate cat pose timeline")
        check(c.frame(time+offset)==d.frame(time+offset),"text selection cannot mutate ball/paw timeline")
    }
    growth.didRenderCompletion(app.art.text,at:time)
    let head=CGPoint(x:170,y:112)
    app.touch.mouseDown(with:event(.leftMouseDown,head)); app.tick()
    app.touch.mouseUp(with:event(.leftMouseUp,head)); app.tick()
    check(isCompletion() && growth.growth.points==2,"already painted completion stays stable during new input without rescoring")
    check(!app.completionText("",at:time+3.1).contains("第 1 天"),"new input cannot extend the original receipt deadline")

    growth=reset(); growth.record(.pet)
    app.toy.start(app.now); app.playMood.beginSession()
    app.playMood.react(at:app.now,sample:0,allowed:true)
    app.playMood.resolve(id:app.now,outcome:.pull,at:app.now,allowed:true)
    check(app.playMood.text(at:app.now) != nil,"an actual ordinary play result exists before completion")
    growth.record(.play); app.tick()
    check(isCompletion() && app.playMood.text(at:app.now)==nil && app.toy.isEngaged(app.now),"completion drops ordinary play text without changing toy attention or creating a backlog")

    for point in [CGPoint(x:170,y:112),CGPoint(x:80,y:140)] {
        growth=reset(); app.toy.start(app.now); app.tick(); _=app.toyKey(124); app.tick()
        check(growth.growth.points==1 && !isCompletion(),"play-first alone must stay silent")
        app.touch.mouseDown(with:event(.leftMouseDown,point)); app.tick()
        check(growth.growth.points==2 && !isCompletion(),"head/body second goal waits for actual release")
        app.touch.mouseDragged(with:event(.leftMouseDragged,CGPoint(x:2,y:2))); app.tick()
        check(!isCompletion(),"crossing silhouette is not release")
        let end=app.motion.petEnd
        app.touch.mouseUp(with:event(.leftMouseUp,CGPoint(x:2,y:2))); app.tick()
        check(isCompletion() && app.motion.petEnd==end && end>app.now,"release speaks while original pet response continues")
    }
    for hidden in [false,true] {
        growth=reset(); app.pet(); growth.record(.play)
        if hidden {app.petVisible=false} else {app.paused=true}
        _=app.completionText("",at:app.now)
        app.petVisible=true; app.paused=false
        check(app.completionText("",at:app.now).isEmpty,"show/resume alone cannot speak an unshown completion")
        app.pet(); app.tick()
        check(isCompletion() && growth.growth.points==2,"next deliberate interaction retries immediately without rescoring")
    }
    print("PASS immediate completion: both goal orders, real head/body/ball release, ordinary speech priority, unchanged cat/ball frames, paint-only dedupe, quiet resume and active retry")
}
