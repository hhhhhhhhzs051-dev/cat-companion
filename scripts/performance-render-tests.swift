import AppKit

@main struct PerformanceRenderTests {
    static func capture(_ view:NSView, scale:Double=2, color:NSColorSpaceName = .deviceRGB, path:String?=nil)->Data {
        let b=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:Int(ceil(view.bounds.width*scale)),pixelsHigh:Int(ceil(view.bounds.height*scale)),bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:color,bytesPerRow:0,bitsPerPixel:0)!
        b.size=view.bounds.size;view.cacheDisplay(in:view.bounds,to:b)
        if let path {try! b.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:path))}
        return Data(bytes:b.bitmapData!,count:b.bytesPerRow*b.pixelsHigh)
    }
    static func transformedCapture(_ view:NSView,scale:Double,phase:Double,color:CGColorSpace)->Data {
        let w=Int(ceil(view.bounds.width*scale))+2,h=Int(ceil(view.bounds.height*scale))+2
        let ctx=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:color,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.translateBy(x:phase,y:Double(h)-phase);ctx.scaleBy(x:scale,y:-scale)
        let previous=NSGraphicsContext.current
        defer {NSGraphicsContext.current=previous}
        NSGraphicsContext.current=NSGraphicsContext(cgContext:ctx,flipped:true)
        view.draw(view.bounds)
        return Data(bytes:ctx.data!,count:ctx.bytesPerRow*h)
    }
    static func inputs(_ scenario:String)->[(CatPose,CatToyFrame)] {
        var motion=CatMotion(now:0,seed:42),toy=CatToy(rollInEnabled:true)
        if scenario != "idle" {toy.start(0);toy.grab(0.1)}
        if scenario == "tail" {toy.move(to:CGPoint(x:0.77,y:CatToy.groundY(0.77)),at:0.2);toy.release(0.3)}
        if scenario == "paw" {toy.move(to:CGPoint(x:0.50,y:0.355),at:0.2);toy.release(0.3)}
        var lastPose=CatPose()
        return (0..<360).map { i in
            let t=0.3+Double(i)/(scenario == "drag" ? 120:60)
            if scenario == "drag" {toy.move(to:CGPoint(x:0.61+sin(t*3)*0.11,y:0.36),at:t)}
            // Same event-driven ball / 30 Hz cat split as build 56.
            let catTime=scenario == "drag" ? 0.3+Double(i/4)/30:t
            var p=motion.frame(catTime,reduced:false,paused:false,engaged:toy.isEngaged(catTime))
            let f=toy.frame(t,canBat:motion.canPlayWithToy(t)),side=max(-1,min(1,f.look*3))
            p.lookX=f.look;p.leftEar=max(p.leftEar,f.attention*(0.675-0.425*side));p.rightEar=max(p.rightEar,f.attention*(0.675+0.425*side))
            if f.paw>0 {p.paw=PawPose(raise:f.paw,toyElbow:f.pawElbow,toyWrist:f.pawWrist,toySide:f.pawSide)}
            if scenario == "drag" {if i%4==0 {lastPose=p};p=lastPose}
            return (p,f)
        }
    }
    static func main() throws {
        setbuf(stdout,nil)
        _=NSApplication.shared
        let args=Array(CommandLine.arguments.dropFirst()),mode=args.first ?? "check"
        let view=try NativeCatView(resources:URL(fileURLWithPath:"src"))
        view.frame=NSRect(x:0,y:0,width:290,height:267)
        view.bedCacheEnabled=mode == "bed" || mode == "both" || mode == "check" || mode == "snapshot"
        view.lookQuantizationEnabled=mode == "look" || mode == "both"
        if mode == "snapshot" {
            let old=try Build56NativeCatView(resources:URL(fileURLWithPath:"src"));old.frame=view.frame
            _=capture(old,path:args[1]+"/before.png");_=capture(view,path:args[1]+"/bed.png")
            return
        }
        if mode == "look-check" {
            let old=try Build56NativeCatView(resources:URL(fileURLWithPath:"src"));old.frame=view.frame
            view.lookQuantizationEnabled=true
            var changed=0,total=0,sum=0,maximum=0
            for look in [-0.9983,-0.2537,-0.0037,0.0037,0.12345,0.8763] {
                let p=CatPose(breath:0.25,leftEar:0.4,rightEar:0.2,lookX:look)
                view.update(p);old.update(p)
                let a=capture(view),b=capture(old)
                for (x,y) in zip(a,b) {let d=abs(Int(x)-Int(y));total += 1;sum += d;maximum=max(maximum,d);if d>0 {changed += 1}}
                for x in stride(from:0.0,through:290,by:2) {for y in stride(from:60.0,through:267,by:2) {
                    precondition(view.touchRegion(CGPoint(x:x,y:y))==old.touchRegion(CGPoint(x:x,y:y)),"Render-only gaze quantization must not change hit geometry")
                }}
            }
            print("PIXELS look changed=\(changed) total=\(total) mean_channel_error=\(Double(sum)/Double(total)) max_delta=\(maximum); hit-grid unchanged")
            view.update(CatPose(lookX:0.125001));let a=capture(view)
            view.update(CatPose(lookX:0.75));_=capture(view)
            view.update(CatPose(lookX:0.125002));let b=capture(view)
            precondition(a==b,"The same quantized gaze cannot depend on prior cache history")
            return
        }
        if mode == "check" {
            let old=try Build56NativeCatView(resources:URL(fileURLWithPath:"src"))
            var different=0,total=0,maxDelta=0
            for scale in [1.0,2.0] {for width in [200.0,290,440,290] {
                let startDifference=different
                for v in [view as NSView,old as NSView] {v.frame=NSRect(x:0,y:0,width:width,height:60+width*1085/1525)}
                for p in [CatPose(),CatPose(breath:0.3),CatPose(eyes:1,head:0.4),CatPose(lookX:0.12345),CatPose(paw:PawPose(raise:0.8,toyElbow:0.2,toyWrist:-0.3))] {
                    view.update(p);old.update(p)
                    let a=capture(view,scale:scale),b=capture(old,scale:scale)
                    for (x,y) in zip(a,b) {total += 1;if x != y {different += 1;maxDelta=max(maxDelta,abs(Int(x)-Int(y)))}}
                }
                print("SCALE",scale,"WIDTH",width,"changed_bytes",different-startDifference)
            }}
            print("PIXELS bed changed_bytes=\(different) total=\(total) max_delta=\(maxDelta)")
            precondition(view.bedCacheBytes>0 && view.bedCacheBytes<=8*1024*1024,"Enabled bed caching must actually retain bounded reusable images")
            precondition(different==0,"Static bed optimization must preserve exact accepted pixels")
            let colors=[CGColorSpaceCreateDeviceRGB(),CGColorSpace(name:CGColorSpace.sRGB)!,CGColorSpace(name:CGColorSpace.displayP3)!]+[NSScreen.main?.colorSpace?.cgColorSpace].compactMap{$0}
            for color in colors {
                for scale in [1.0,2.0] {for phase in [0.0,0.25,0.5] {
                    let a=transformedCapture(view,scale:scale,phase:phase,color:color)
                    let b=transformedCapture(old,scale:scale,phase:phase,color:color)
                    let changed=zip(a,b).filter{$0 != $1}.count
                    print("CONTEXT",color.name ?? "unnamed" as CFString,scale,phase,"changed_bytes",changed)
                    precondition(changed==0,"Color and pixel-phase cache equivalence")
                }}
            }
            _=capture(view)
            let first=view.bedCacheBytes
            view.viewDidChangeBackingProperties()
            precondition(view.bedCacheBytes==0,"Backing change releases old bed images")
            _=capture(view);precondition(view.bedCacheBytes==first)
            view.lookQuantizationEnabled=true
            view.update(CatPose(lookX:0.125001));_=capture(view);let image=view.renderedCatImage
            view.update(CatPose(lookX:0.125002));_=capture(view)
            precondition(view.renderedCatImage === image,"Subpixel-equivalent gaze must reuse a raster")
            print("PASS bounded bed reuse and subpixel gaze reuse")
            return
        }
        let scenario=args.count>1 ? args[1]:"idle",frames=inputs(scenario)
        for i in 0...48 {view.update(CatPose(breath:Double(i)/48));_=capture(view)}
        let before=view.catRasterizations,cpu=clock(),start=ProcessInfo.processInfo.systemUptime
        var times:[Double]=[]
        for (p,f) in frames {autoreleasepool {
            let t=ProcessInfo.processInfo.systemUptime
            view.update(p);view.toyFrame=f;_=capture(view)
            times.append((ProcessInfo.processInfo.systemUptime-t)*1000)
        }}
        let sorted=times.sorted()
        print("BENCH mode=\(mode) scenario=\(scenario) frames=\(frames.count) cpu_s=\(Double(clock()-cpu)/Double(CLOCKS_PER_SEC)) wall_s=\(ProcessInfo.processInfo.systemUptime-start) p50_ms=\(sorted[180]) p95_ms=\(sorted[342]) rasters=\(view.catRasterizations-before) bed_bytes=\(view.bedCacheBytes) idle_bytes=\(view.idleCacheBytes)")
    }
}
