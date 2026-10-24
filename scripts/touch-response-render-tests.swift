import AppKit

@main struct TouchResponseRenderTests {
    static func capture(_ view:NSView,_ scale:Double=2)->Data {
        let b=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:Int(ceil(view.bounds.width*scale)),pixelsHigh:Int(ceil(view.bounds.height*scale)),bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        b.size=view.bounds.size;view.cacheDisplay(in:view.bounds,to:b)
        return Data(bytes:b.bitmapData!,count:b.bytesPerRow*b.pixelsHigh)
    }
    static func main() throws {
        _=NSApplication.shared;setbuf(stdout,nil)
        let source=URL(fileURLWithPath:"src")
        let baseline=try NativeCatView(resources:source),preview=try NativeCatView(resources:source)
        var bytes=0
        for width in [200.0,290,440] {for scale in [1.0,2.0] {
            for v in [baseline,preview] {v.frame=NSRect(x:0,y:0,width:width,height:60+width*1085/1525)}
            for time in [0.0,0.1,0.3,0.7,1.0,2.0] {
                var a=CatMotion(now:0,seed:42),b=CatMotion(now:0,seed:42,refinedTouch:true)
                a.pet(0);b.pet(0)
                baseline.update(a.frame(time,reduced:false,paused:false));preview.update(b.frame(time,reduced:false,paused:false))
                let x=capture(baseline,scale),y=capture(preview,scale)
                precondition(x==y,"head-click pixels must stay exact");bytes += x.count
            }
            for region in [CatTouchRegion.head,.back] {
                var m=CatMotion(now:0,seed:42,refinedTouch:true)
                if region == .head {m.pet(1);m.stroke(.head,at:1)}else{m.touchBack(1)}
                for time in [1.0,1.05,1.12,1.18,1.3] {
                    preview.update(m.frame(time,reduced:false,paused:false));_ = capture(preview,scale)
                    func point(_ x:Double,_ y:Double)->CGPoint {CGPoint(x:x*width/290,y:60+(y-60)*width/290)}
                    precondition(preview.touchRegion(point(170,112)) == .head)
                    precondition(preview.touchRegion(point(80,140)) == .back)
                    precondition(preview.touchRegion(point(145,222)) == .bed)
                    precondition(preview.touchRegion(CGPoint(x:0,y:61)) == .none)
                }
            }
        }}
        print("PASS unchanged head-click RGBA bytes=\(bytes); new ear/head geometry landmarks at 200/290/440pt, 1x/2x")
        // Same deterministic idle stream, renderer and cache budget on both sides.
        // CPU timings are offscreen diagnostics, not a visible-window benchmark.
        for refined in [false,true] {
            let v=try NativeCatView(resources:source);v.frame=NSRect(x:0,y:0,width:290,height:267)
            var m=CatMotion(now:0,seed:42,refinedTouch:refined)
            let cpu=clock(),start=ProcessInfo.processInfo.systemUptime
            for i in 0..<360 {autoreleasepool {
                v.update(m.frame(Double(i)/30,reduced:false,paused:false));_=capture(v)
            }}
            print("IDLE refined=\(refined) frames=360 cpu_s=\(Double(clock()-cpu)/Double(CLOCKS_PER_SEC)) wall_s=\(ProcessInfo.processInfo.systemUptime-start) rasters=\(v.catRasterizations) idle_bytes=\(v.idleCacheBytes) bed_bytes=\(v.bedCacheBytes)")
            precondition(v.bedCacheBytes==0 && v.idleCacheBytes<=64*1024*1024)
        }
    }
}
