import AppKit

func runMenuTests(_ unused:PetApp) {
    func check(_ ok:Bool,_ message:String) {if !ok {fputs("FAIL: \(message)\n",stderr);exit(1)}}
    let source=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("src")
    func fresh()->PetApp {
        let a=PetApp();a.art=try! NativeCatView(resources:source)
        a.panel=PetPanel(contentRect:NSRect(x:60,y:200,width:290,height:267),styleMask:.borderless,backing:.buffered,defer:false)
        let container=NSView(frame:NSRect(x:0,y:0,width:290,height:267));a.panel.contentView=container
        a.art.frame=container.bounds;container.addSubview(a.art)
        a.touch=PetTouchView(frame:container.bounds);a.touch.owner=a;container.addSubview(a.touch)
        a.motion=CatMotion(now:a.now,seed:42);a.active=true
        a.copy=["pet":["私人摸头句。"]]
        return a
    }
    func pump(_ a:PetApp,_ duration:Double) {
        let end=a.now+duration
        while a.now<end {a.tick();RunLoop.main.run(until:Date().addingTimeInterval(1.0/30))}
    }
    func release(_ a:PetApp,_ x:Double) {
        a.toy.start(a.now);a.playMood.beginSession();a.playMood.react(at:a.now,sample:0,allowed:true)
        a.beginToyContact();a.moveToy(CGPoint(x:x*290,y:60+0.355*290));a.toy.release(a.now);a.tick()
    }
    let a=fresh()
    a.tick();check(!a.art.bedCacheEnabled && !a.art.lookQuantizationEnabled,"idle starts with no extra cache or gaze quantization")
    release(a,0.55)
    check(a.art.text.isEmpty && a.art.bedCacheEnabled,"ball release stays quiet; active cache uses original tick")
    pump(a,0.4);check(a.art.text.isEmpty,"unfinished pull must not speak success")
    pump(a,1.1);check(a.art.text=="回来啦。","actual pull outcome reaches normal text routing")
    let spoken=a.art.text
    a.beginToyContact();a.moveToy(CGPoint(x:0.61*290,y:60+0.355*290));a.toy.release(a.now)
    pump(a,0.5);check(a.art.text==spoken,"second hit cannot replace or extend session text")
    pump(a,1.5);check(a.art.text.isEmpty,"ordinary result expires without backlog")
    a.pet();check(a.art.text=="私人摸头句。","head input still responds with private text")
    check(a.toy.isOut,"petting still leaves the ball in the bed")
    a.motion=CatMotion(now:a.now,seed:42);a.toy=CatToy(rollInEnabled:true);a.tick()
    check(!a.art.bedCacheEnabled,"idle promptly releases the active cache")
    release(a,0.55);a.active=false;a.tick()
    check(!a.art.bedCacheEnabled,"hidden activity releases the cache even on early-return paths")

    for blocked in ["pet","letter","pause","hidden","completion"] {
        let b=fresh();release(b,0.55)
        switch blocked {
        case "pet":b.touchBack()
        case "letter":
            b.letterController=CatLetterController(text:"",stationeryURL:source.appendingPathComponent("assets/letter-stationery-v1.png"))
            b.showLetter()
        case "pause":b.paused=true
        case "hidden":b.active=false
        default:
            let growth=CatGrowthController(owner:b);b.growthController=growth
            growth.record(.pet);growth.record(.play);b.tick()
            check(b.art.text.contains("第 1 天"),"completion immediately takes priority over pending play")
            growth.didRenderCompletion(b.art.text,at:b.now)
        }
        pump(b,1.6)
        check(b.playMood.text(at:b.now)==nil,"\(blocked) drops ordinary result rather than queues it")
        b.letterController?.window?.orderOut(nil)
        b.active=true;b.paused=false;pump(b,0.1)
        check(b.playMood.text(at:b.now)==nil,"\(blocked) resume cannot replay result")
        b.panel.orderOut(nil)
    }
    let temp=FileManager.default.temporaryDirectory.appendingPathComponent("cat-context-level-"+UUID().uuidString)
    try! FileManager.default.createDirectory(at:temp,withIntermediateDirectories:true)
    defer {try? FileManager.default.removeItem(at:temp)}
    for points in [4,6,19] {
        let b=fresh(),store=CatGrowthStore(url:temp.appendingPathComponent("\(points).json")),day=CatGrowth.dayKey(Date(),calendar:.current)
        let snapshot=CatGrowthSnapshot(unlockedRewards:[0],completionShownDay:day,points:points,companionDays:(points+1)/2,
            completed:Set(CatGrowthGoal.allCases),day:day,ballSelected:true,decoration:nil)
        try! store.save(snapshot)
        b.growthController=CatGrowthController(owner:b,store:store);b.lastPet=0
        b.pet()
        let level=CatLevelProgress(points:points).level
        check(CatPetLines.candidates(base:["私人摸头句。"],level:level).contains(b.art.text),"real head handler selects only earned level's pool")
        check(points<6 ? b.art.text=="私人摸头句。":b.art.text != "私人摸头句。","new level pool participates in the existing no-repeat selection")
        check(b.copy["pet"] as? [String]==["私人摸头句。"],"level feedback cannot overwrite private copy")
        check(b.growthController!.growth.points==points && b.growthController!.ballSelected,"level feedback cannot change progress or reward choice")
        check(try! store.load()==snapshot,"no new save field or hidden migration for unlocked phrases")
    }
    print("PASS context integration: real result routing, level boundary/private-copy preservation, no ordinary backlog, completion priority, unchanged progress, cache active/idle/hide lifecycle")
}
