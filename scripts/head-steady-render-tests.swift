import AppKit

@main struct HeadSteadyRenderTests {
    static func capture(_ view:NSView,_ scale:Double)->NSBitmapImageRep {
        let b=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:Int(ceil(view.bounds.width*scale)),pixelsHigh:Int(ceil(view.bounds.height*scale)),bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        b.size=view.bounds.size;view.cacheDisplay(in:view.bounds,to:b);return b
    }
    static func main() throws {
        _=NSApplication.shared;setbuf(stdout,nil)
        let source=URL(fileURLWithPath:"src"),view=try NativeCatView(resources:source)
        var bodyBytes=0,oldShiftBytes=0
        for width in [200.0,290,440] {for scale in [1.0,2.0] {
            view.frame=NSRect(x:0,y:0,width:width,height:60+width*1085/1525)
            let idle=CatPose(eyes:1,breath:0.3);view.update(idle);let neutral=capture(view,scale)
            for moving in [false,true] {
                var m=CatMotion(now:0,seed:42,refinedTouch:true,headPetLeans:false)
                m.pet(1);if moving {m.stroke(.head,at:1.01)}
                var p=m.frame(1.3,reduced:false,paused:false);p.breath=idle.breath
                precondition(p.eyes==1 && p.lean==0)
                view.update(p);let next=capture(view,scale)
                p.lean=1;view.update(p);let old=capture(view,scale)
                // Back-coat crop away from face/ears. Keep breathing AND eye
                // compositing identical: enabling the existing eyelid kernel
                // resamples the source even outside the eye mask. This compares
                // spatial motion, not that unrelated open/closed sampling path.
                let x0=Int(40*width/290*scale),x1=Int(96*width/290*scale)
                let y0=Int((60+70*width/290)*scale),y1=Int((60+105*width/290)*scale)
                for y in y0..<y1 {for x in x0..<x1 {for c in 0..<4 {
                    let n=neutral.bitmapData![y*neutral.bytesPerRow+x*4+c]
                    precondition(n==next.bitmapData![y*next.bytesPerRow+x*4+c],"head input must leave the back-coat pixels stationary")
                    bodyBytes += 1
                    if n != old.bitmapData![y*old.bytesPerRow+x*4+c] {oldShiftBytes += 1}
                }}}
                view.update(m.frame(1.3,reduced:false,paused:false))
                func point(_ x:Double,_ y:Double)->CGPoint {CGPoint(x:x*width/290,y:60+(y-60)*width/290)}
                precondition(view.touchRegion(point(170,112)) == .head)
                precondition(view.touchRegion(point(80,140)) == .back)
                precondition(view.touchRegion(point(145,222)) == .bed)
                precondition(view.touchRegion(CGPoint(x:0,y:61)) == .none)
            }
        }}
        precondition(oldShiftBytes>0,"crop must detect the original whole-cat lean")
        print("PASS steady-body pixels: \(bodyBytes) back-coat RGBA bytes unchanged; old lean changes \(oldShiftBytes); hit landmarks pass at 200/290/440pt 1x/2x")
        for leanEnabled in [true,false] {
            let v=try NativeCatView(resources:source);v.frame=NSRect(x:0,y:0,width:290,height:267)
            var m=CatMotion(now:0,seed:42,refinedTouch:true,headPetLeans:leanEnabled)
            let start=clock()
            for i in 0..<360 {autoreleasepool {v.update(m.frame(Double(i)/30,reduced:false,paused:false));_=capture(v,2)}}
            print("IDLE headLean=\(leanEnabled) rasters=\(v.catRasterizations) idle_bytes=\(v.idleCacheBytes) bed_bytes=\(v.bedCacheBytes) cpu_s=\(Double(clock()-start)/Double(CLOCKS_PER_SEC))")
            precondition(v.bedCacheBytes==0 && v.idleCacheBytes<=64*1024*1024)
        }
    }
}
