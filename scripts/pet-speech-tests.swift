import AppKit

// Existing production handlers and monotonic clock; no running app interaction,
// installed app, global input, real growth store or user-copy mutation.
func runMenuTests(_ unused:PetApp) {
    func check(_ ok:Bool,_ message:String) {if !ok {fputs("FAIL: \(message)\n",stderr);exit(1)}}
    let source=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("src")
    func fresh()->PetApp {
        let a=PetApp();a.art=try! NativeCatView(resources:source)
        a.panel=PetPanel(contentRect:NSRect(x:0,y:0,width:290,height:267),styleMask:.borderless,backing:.buffered,defer:false)
        let container=NSView(frame:NSRect(x:0,y:0,width:290,height:267))
        a.panel.contentView=container;a.art.frame=container.bounds;container.addSubview(a.art)
        a.touch=PetTouchView(frame:container.bounds);a.touch.owner=a;container.addSubview(a.touch)
        a.motion=CatMotion(now:a.now,seed:42);a.active=true
        a.copy=["pet":["普通短句甲。","普通短句乙。"]]
        return a
    }
    func pump(_ a:PetApp,_ duration:Double,stroke:Bool=false) {
        let end=a.now+duration
        while a.now<end {
            if stroke {a.stroke(.head)}
            a.tick();RunLoop.main.run(until:Date().addingTimeInterval(0.015))
        }
    }
    func press(_ a:PetApp,_ down:Bool,body:Bool=false) {
        let p=body ? CGPoint(x:80,y:140):CGPoint(x:170,y:112)
        let type:NSEvent.EventType=down ? .leftMouseDown:.leftMouseUp
        let e=NSEvent.mouseEvent(with:type,location:NSPoint(x:p.x,y:267-p.y),modifierFlags:[],timestamp:0,windowNumber:a.panel.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:1)!
        if down {a.touch.mouseDown(with:e)}else{a.touch.mouseUp(with:e)}
        a.tick()
    }
    func click(_ a:PetApp,body:Bool=false) {press(a,true,body:body);press(a,false,body:body)}

    let a=fresh()
    click(a,body:true);check(a.art.text.isEmpty,"body alone keeps its quiet nonverbal response")
    click(a)
    check(!a.art.text.isEmpty,"body -> head must produce ordinary speech even while the body motion is active")
    let first=a.art.text,started=a.now
    for _ in 0..<6 {
        click(a,body:true);check(a.art.text==first,"body neither creates a new line nor cuts off the current head line")
        click(a);check(a.art.text==first,"rapid body/head alternation preserves the same line, not random text spam")
        pump(a,0.08)
    }
    press(a,true)
    pump(a,max(0,started+2.15-a.now),stroke:true)
    check(a.touch.hasContact && a.now<a.motion.petEnd,"held pet still runs original motion")
    check(a.art.text.isEmpty,"continued stroking must not extend ordinary speech indefinitely")
    press(a,false);click(a)
    check(!a.art.text.isEmpty && a.art.text != first,"new head gesture can speak after text expires even though motion is still active")

    let b=fresh()
    let growth=CatGrowthController(owner:b);b.growthController=growth;growth.record(.play)
    press(b,true);check(!b.art.text.contains("第 1 天"),"completion still waits for initial release")
    press(b,false)
    let line=b.art.text
    check(line.contains("第 1 天"),"second goal release still presents completion immediately")
    growth.didRenderCompletion(line,at:b.now)
    for _ in 0..<7 {
        click(b,body:true);click(b);check(b.art.text==line,"completion remains stable over body/head switching")
        pump(b,0.34)
    }
    pump(b,0.8)
    check(b.art.text.isEmpty,"ordinary lines hidden by completion must not be replayed after it expires")
    click(b);check(!b.art.text.isEmpty && b.art.text != line,"fresh head click after completion can speak normally")
    check(growth.growth.points==2 && growth.completionFeedback.shownDay>0,"ordinary speech does not rescore or reset daily receipt")
    for rest in [false,true] {
        let c=fresh();click(c);check(!c.art.text.isEmpty,"fresh ordinary line before lifecycle cancellation")
        c.settingsReady=true;c.paused=rest;c.petVisible=rest
        c.syncActivity(force:true)
        c.settingsReady=false;c.active=true;c.paused=false;c.petVisible=true;c.tick()
        check(c.art.text.isEmpty,"hide/rest resume cannot replay an old ordinary line")
        click(c);check(!c.art.text.isEmpty,"new head click after quiet resume can respond")
    }
    print("PASS ordinary pet speech: body-to-head recovery, stable rapid alternation, independent expiry during held motion, fresh input after expiry, completion priority/no backlog, quiet lifecycle resume, unchanged daily score")
}
