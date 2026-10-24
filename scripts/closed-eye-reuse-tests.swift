import AppKit

@main struct ClosedEyeReuseTests {
    static func capture(_ view:NSView,scale:Double=2)->Data {
        let b=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:Int(ceil(view.bounds.width*scale)),
            pixelsHigh:Int(ceil(view.bounds.height*scale)),bitsPerSample:8,samplesPerPixel:4,
            hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        b.size=view.bounds.size;view.cacheDisplay(in:view.bounds,to:b)
        return Data(bytes:b.bitmapData!,count:b.bytesPerRow*b.pixelsHigh)
    }
    static func check(_ ok:Bool,_ message:String) {
        if !ok {fputs("FAIL closed-eye reuse: \(message)\n",stderr);exit(1)}
    }
    static func transformed(_ view:NSView,scale:Double,phase:Double,color:CGColorSpace)->Data {
        let w=Int(ceil(view.bounds.width*scale))+2,h=Int(ceil(view.bounds.height*scale))+2
        let ctx=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,
            space:color,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.translateBy(x:phase,y:Double(h)-phase);ctx.scaleBy(x:scale,y:-scale)
        let prior=NSGraphicsContext.current
        defer {NSGraphicsContext.current=prior}
        NSGraphicsContext.current=NSGraphicsContext(cgContext:ctx,flipped:true)
        view.draw(view.bounds)
        return Data(bytes:ctx.data!,count:ctx.bytesPerRow*h)
    }
    static func main() throws {
        _=NSApplication.shared
        let view=try NativeCatView(resources:URL(fileURLWithPath:"src"))
        let original=try Build59NativeCatView(resources:URL(fileURLWithPath:"src"))
        for v in [view as NSView,original as NSView] {v.frame=NSRect(x:0,y:0,width:290,height:267)}
        for breath in [0.0,0.2,0.4,0.6,0.8,1.0] {
            let p=CatPose(eyes:1,breath:breath,leftEar:0.85,rightEar:0.28,head:-0.55)
            view.update(p);original.update(p)
            let pair=autoreleasepool {(capture(view),capture(original))}
            check(pair.0==pair.1,"complete closed-eye image must match frozen build59")
        }
        check(view.fullClosureCompositions==1,"changing breath during held closed eyes must not recomposite eyelids every frame")
        print("PASS full closed-eye source reused across breathing with exact build59 pixels")
        check(view.hasHeldClosedSource,"closed endpoint actually retains the intermediate")
        view.update(CatPose(eyes:0.8))
        check(!view.hasHeldClosedSource,"opening releases the endpoint even without a draw")
        _=capture(view)
        view.update(CatPose(eyes:1));_=capture(view)
        check(view.fullClosureCompositions==2,"fresh closed sequence builds once, no stale image")
        view.viewDidChangeBackingProperties()
        check(!view.hasHeldClosedSource,"backing change invalidates intermediate")
        _=capture(view);check(view.fullClosureCompositions==3,"backing change can rebuild safely")
        view.useV1Rendering=true;check(!view.hasHeldClosedSource,"legacy comparison does not retain cache")
        view.useV1Rendering=false
        var groom=CatPose(eyes:1);groom.groomingProfile=true
        view.update(groom);original.update(groom)
        check(capture(view)==capture(original) && !view.hasHeldClosedSource,"grooming keeps its accepted special-eye path")
        view.cacheEnabled=false;view.update(CatPose(eyes:1));_=capture(view)
        check(!view.hasHeldClosedSource,"uncached reference bypasses endpoint reuse")
        view.cacheEnabled=true
        let samplePoses=[CatPose(),CatPose(eyes:0.5),CatPose(eyes:0.997),CatPose(eyes:0.999),
            CatPose(eyes:1,breath:0.37,leftEar:0.25,rightEar:0.1,head:0.35,lookX:-0.12345),
            CatPose(eyes:1,breath:0.8,leftEar:0.85,rightEar:0.28,head:-0.55),
            CatPose(eyes:0.5),CatPose()]
        var compared=0
        for scale in [1.0,2.0] {for width in [200.0,290,440] {
            for v in [view as NSView,original as NSView] {v.frame=NSRect(x:0,y:0,width:width,height:60+width*1085/1525)}
            for p in samplePoses {
                view.update(p);original.update(p)
                autoreleasepool {
                    let a=capture(view,scale:scale),b=capture(original,scale:scale)
                    check(a==b,"all pixels at \(width)pt / \(scale)x including endpoint joins")
                    compared += a.count
                }
            }
        }}
        for v in [view as NSView,original as NSView] {v.frame=NSRect(x:0,y:0,width:290,height:267)}
        let closed=CatPose(eyes:1,breath:0.7,leftEar:0.85,rightEar:0.28,head:-0.55)
        view.update(closed);original.update(closed)
        for color in [CGColorSpaceCreateDeviceRGB(),CGColorSpace(name:CGColorSpace.sRGB)!,CGColorSpace(name:CGColorSpace.displayP3)!] {
            for scale in [1.0,2.0] {for phase in [0.0,0.25,0.5] {
                autoreleasepool {
                    check(transformed(view,scale:scale,phase:phase,color:color)==transformed(original,scale:scale,phase:phase,color:color),
                          "color-space and fractional pixel-phase equality")
                }
            }}
        }
        for release in [2.0,5.5] {for region in [CatTouchRegion.head,.back] {
            var motion=CatMotion(now:0,seed:42,refinedTouch:true,headPetLeans:false)
            if region == .back {motion.touchBack(0)} else {motion.pet(0);motion.stroke(.head,at:0)}
            for i in 0...174 {
                let t=Double(i)/30
                if t<release {motion.stroke(region,at:t)}
                else if t-1/30<release {motion.endStroke(t)}
                let p=motion.frame(t,reduced:false,paused:false)
                if t>=0.2 && t<min(5,release) {check(p.eyes==1,"fully closed hold")}
                // Later ordinary idle blinks are allowed; verify the release itself.
                if t>min(5,release)+0.25 && t<min(5,release)+0.75 {check(p.eyes==0,"original release and 5s cap")}
                view.update(p);original.update(p)
                autoreleasepool {check(capture(view)==capture(original),"head/body real-clock trace pixels")}
                if i%5==0 {
                    for x in stride(from:0.0,through:290,by:12) {for y in stride(from:60.0,through:267,by:12) {
                        check(view.touchRegion(CGPoint(x:x,y:y))==original.touchRegion(CGPoint(x:x,y:y)),"unchanged hit geometry")
                    }}
                }
            }
        }}
        view.update(CatPose());check(!view.hasHeldClosedSource,"idle has no closed-eye intermediate")
        print("PASS endpoint lifecycle, 200/290/440pt 1x/2x output sampling (\(compared) bytes), colors/phases, real 2s/5s head/body traces and hit grid")
    }
}
