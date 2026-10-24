import AppKit

func runMenuTests(_ app:PetApp) {
    // The shared suite finishes NSApp launch before any windows exist; keep
    // that ordering so OS launch focus cannot arrive during the letter test.
    runExistingMenuTests(app)
    runAccessoryPaletteTests()
    func check(_ ok:Bool,_ message:String) {if !ok {print("FAIL: \(message)");exit(1)}}
    check(app.isPlayPreview && app.growthStore==nil,"accessory demo never opens real growth storage")
    let prefs=UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?
    app.art=try! NativeCatView(resources:URL(fileURLWithPath:"src"))
    app.panel=PetPanel(contentRect:NSRect(x:100,y:100,width:290,height:267),styleMask:[.borderless],backing:.buffered,defer:false)
    let container=NSView(frame:NSRect(x:0,y:0,width:290,height:267));app.panel.contentView=container
    app.art.frame=container.bounds;container.addSubview(app.art)
    app.touch=PetTouchView(frame:container.bounds);app.touch.owner=app;container.addSubview(app.touch)
    app.setupControls(in:container)
    let growth=CatGrowthController(owner:app);app.growthController=growth
    growth.prepareAccessoryDemo();growth.accessory.frame=container.bounds
    container.addSubview(growth.accessory,positioned:.above,relativeTo:app.art)
    app.active=true;app.paused=false;app.petVisible=true
    app.toy.finish(app.now,immediate:true)
    let saved=growth.growth.snapshot(ballSelected:growth.ballSelected,decorations:growth.decorations)
    check(saved.points==32 && growth.isUnlocked(.flower) && growth.isUnlocked(.fish),"demo uses simulated unlocked rewards")
    let flowerButton=NSButton(),fishButton=NSButton()
    flowerButton.tag=CatGrowthReward.flower.rawValue;fishButton.tag=CatGrowthReward.fish.rawValue
    let flowerPoint=CGPoint(x:270,y:232),fishPoint=CGPoint(x:256,y:184)
    if !growth.accessory.containsInteraction(flowerPoint) {growth.chooseReward(flowerButton)}
    if !growth.accessory.containsInteraction(fishPoint) {growth.chooseReward(fishButton)}
    check(growth.accessory.containsInteraction(flowerPoint) && growth.accessory.containsInteraction(fishPoint),"placing fish must keep the already placed flower visible and interactive")
    growth.chooseReward(flowerButton)
    check(!growth.accessory.containsInteraction(flowerPoint) && growth.accessory.containsInteraction(fishPoint),"hiding flower keeps fish")
    growth.chooseReward(flowerButton);growth.chooseReward(fishButton)
    check(growth.accessory.containsInteraction(flowerPoint) && !growth.accessory.containsInteraction(fishPoint),"hiding fish keeps flower")
    growth.chooseReward(fishButton)
    let ballButton=NSButton();ballButton.tag=CatGrowthReward.sageBall.rawValue
    growth.chooseReward(ballButton);growth.chooseReward(ballButton)
    check(growth.accessory.selections == [.flower,.fish],"changing ball color does not replace either decoration")
    func event(_ type:NSEvent.EventType,_ p:CGPoint)->NSEvent {
        NSEvent.mouseEvent(with:type,location:NSPoint(x:p.x,y:267-p.y),modifierFlags:[],timestamp:app.now,windowNumber:app.panel.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:1)!
    }
    app.toy.start(app.now-1);app.toy.grab(app.now)
    app.moveToy(fishPoint)
    // The accepted ball clamp is x<=0.77 (223.3pt), not the fish center.
    // At that x the sloped bed clamps y to about169.13pt. Its16pt grab
    // halo and the fish's padded upper-left edge overlap at (239,169).
    let overlapPoint=CGPoint(x:239,y:169)
    check(app.art.containsToy(overlapPoint) && growth.accessory.containsInteraction(overlapPoint),"test covers the real ball-grab halo overlapping the fish hit target")
    app.touch.mouseDown(with:event(.leftMouseDown,overlapPoint))
    check(app.touch.playing && app.touch.accessoryContact == nil,"the lifted ball retains input priority over the fish")
    app.touch.mouseUp(with:event(.leftMouseUp,overlapPoint))
    check(!growth.accessory.sway(for:.fish).isActive,"releasing the ball never taps the fish behind it")
    app.toy.finish(app.now,immediate:true);app.art.toyFrame=CatToyFrame()
    for reward in [CatGrowthReward.fish,.flower] {
        let other:CatGrowthReward=reward == .flower ? .fish:.flower
        let r=growth.accessory.interactionRect(for:reward),p=CGPoint(x:r.midX,y:r.midY)
        let origin=app.panel.frame.origin,petEnd=app.motion.petEnd
        check(growth.accessory.hitTest(p)==nil,"decoration overlay never steals the original input view")
        app.touch.mouseDown(with:event(.leftMouseDown,p))
        check(app.touch.accessoryContact == reward && !app.touch.playing,"a decoration press belongs to the exact decoration")
        app.touch.mouseUp(with:event(.leftMouseUp,p))
        check(growth.accessory.sway(for:reward).isActive && !growth.accessory.sway(for:other).isActive,"real release starts only the clicked response")
        check(app.motion.petEnd==petEnd && app.panel.frame.origin==origin,"tap does not pet or move the cat")
        growth.accessory.advance(to:app.now+3,enabled:true,reduced:false)
        check(!growth.accessory.sway(for:reward).isActive && growth.accessory.sway(for:reward).angle==0,"real view settles and stops")
        // An attached view inherits its parent's dirty region; use an isolated
        // view so this assertion measures only our idle invalidations.
        let idleProbe=CatGrowthAccessoryView(frame:container.bounds);idleProbe.selections=[.flower,.fish]
        idleProbe.needsDisplay=false
        check(!idleProbe.needsDisplay,"idle probe begins without an inherited dirty parent")
        for i in 0..<3600 {idleProbe.advance(to:Double(i),enabled:true,reduced:false)}
        check(!idleProbe.needsDisplay,"idle ticks never invalidate the accessory")
        app.touch.mouseDown(with:event(.leftMouseDown,p))
        let q=CGPoint(x:p.x-12,y:p.y)
        app.touch.mouseDragged(with:event(.leftMouseDragged,q));app.touch.mouseUp(with:event(.leftMouseUp,q))
        check(app.panel.frame.origin != origin && !growth.accessory.sway(for:reward).isActive,"dragging from a decoration moves the bed, not a tap")
        app.panel.setFrameOrigin(origin)
        app.paused=true;app.touch.mouseDown(with:event(.leftMouseDown,p));app.touch.mouseUp(with:event(.leftMouseUp,p))
        check(!growth.accessory.sway(for:reward).isActive,"resting cat does not animate accessories");app.paused=false
        growth.accessory.tap(reward,at:app.now,reduced:false);growth.accessory.advance(to:app.now+0.1,enabled:true,reduced:false)
        check(growth.accessory.sway(for:reward).angle != 0 && growth.accessory.sway(for:other).angle==0,"view motion belongs only to clicked item")
        growth.accessory.advance(to:app.now+0.2,enabled:true,reduced:true)
        check(growth.accessory.sway(for:reward).angle==0 && !growth.accessory.sway(for:reward).isActive,"live reduced motion cancels without replay")
        growth.accessory.tap(reward,at:app.now+1,reduced:false);growth.accessory.advance(to:app.now+1.1,enabled:false,reduced:false)
        check(!growth.accessory.sway(for:reward).isActive,"hide/read/rest cancellation stops motion")
        check(!growth.accessory.containsInteraction(CGPoint(x:170,y:112)) && !growth.accessory.containsInteraction(CGPoint(x:145,y:222)),"head and central bed stay unblocked")
        app.touch.mouseDown(with:event(.leftMouseDown,p))
        let o=growth.accessory.interactionRect(for:other)
        app.touch.mouseUp(with:event(.leftMouseUp,CGPoint(x:o.midX,y:o.midY)))
        check(!growth.accessory.sway(for:reward).isActive && !growth.accessory.sway(for:other).isActive,"pressing one then releasing on the other triggers neither")
    }
    growth.accessory.tap(.flower,at:10000,reduced:false);growth.accessory.tap(.fish,at:10000,reduced:false)
    growth.accessory.advance(to:10000.12,enabled:true,reduced:false)
    let fishAngle=growth.accessory.sway(for:.fish).angle
    growth.chooseReward(flowerButton)
    check(fishAngle != 0 && growth.accessory.sway(for:.fish).angle==fishAngle && !growth.accessory.sway(for:.flower).isActive,"hiding flower during motion leaves fish's independent motion intact")
    growth.chooseReward(flowerButton)
    check(!growth.accessory.sway(for:.flower).isActive,"re-showing a hidden flower never replays its old sway")
    growth.accessory.cancelMotion()
    check(growth.growth.snapshot(ballSelected:growth.ballSelected,decorations:growth.decorations)==saved,"accessories never score, unlock, or change reward selection")
    for width in [200.0,290,440] {for scale in [1.0,2.0] {for reward in [CatGrowthReward.flower,.fish] {
        let frame=NSRect(x:0,y:0,width:width,height:60+width*1085/1525)
        let next=CatGrowthAccessoryView(frame:frame)
        next.selections=[.flower,.fish]
        func pixels(_ view:NSView)->Data {
            let b=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:Int(ceil(frame.width*scale)),pixelsHigh:Int(ceil(frame.height*scale)),bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
            b.size=frame.size;view.cacheDisplay(in:view.bounds,to:b);return Data(bytes:b.bitmapData!,count:b.bytesPerRow*b.pixelsHigh)
        }
        let baseline=pixels(next)
        next.tap(reward,at:1,reduced:false);next.advance(to:1.12,enabled:true,reduced:false)
        check(pixels(next) != baseline,"tap changes visible pixels, not only model state")
        next.advance(to:4,enabled:true,reduced:false);check(pixels(next)==baseline,"settled accessory returns to exact accepted pixels")
        let r=next.interactionRect(for:reward)
        check(r.width>=24 && r.height>=24,"normal supported sizes have usable local hit area")
        check(!next.interactionRect(for:.flower).intersects(next.interactionRect(for:.fish)),"two targets never overlap, even at smallest supported size")
        check(frame.contains(next.drawingRect(for:reward)),"larger decoration stays inside the existing window")
    }}}
    check(prefs==UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?,"preview never writes formal preferences")
    app.panel.orderOut(nil);app.growthController=nil
    print("PASS dual accessories: independent selection/tap/sway/hide, ball tint isolation, exact release ownership, drag/rest/reduced/cancel, zero scoring, no idle redraw, settled pixels and separate targets at 3 sizes 2 scales")
}
