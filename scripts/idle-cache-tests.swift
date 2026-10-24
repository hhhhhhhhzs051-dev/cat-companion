import AppKit
import CoreImage

@main struct IdleCacheTests {
    static func main() throws {
        let view=try NativeCatView(resources:URL(fileURLWithPath:"src"))
        let old=try LegacyNativeCatView(resources:URL(fileURLWithPath:"src"))
        func capture(_ target:NSView)->Data {
            let width=Int(target.bounds.width*2),height=Int(target.bounds.height*2)
            let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,
                bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
            rep.size=target.bounds.size
            target.cacheDisplay(in:target.bounds,to:rep)
            return Data(bytes:rep.bitmapData!,count:rep.bytesPerRow*rep.pixelsHigh)
        }
        func size(_ width:Double) {
            view.frame=NSRect(x:0,y:0,width:width,height:60+width*0.715)
            old.frame=view.frame
        }
        size(290)
        func check(_ condition:Bool,_ message:String) {
            if !condition {fputs("FAIL \(message)\n",stderr);exit(1)}
        }
        let mode=CommandLine.arguments.dropFirst().first ?? "check"
        if mode != "check" {
            precondition(mode == "old" || mode == "new")
            var motion=CatMotion(now:0,seed:55)
            let start=ProcessInfo.processInfo.systemUptime,cpu=clock()
            var checksum:UInt64=0
            for i in 0..<900 {
                autoreleasepool {
                    let pose=motion.frame(Double(i)/30,reduced:false,paused:false)
                    if mode == "old" {old.update(pose)}else{view.update(pose)}
                    let data=capture(mode == "old" ? old:view)
                    // Fixed small sample; drawing is complete before capture returns.
                    for offset in stride(from:0,to:data.count,by:997) {checksum &+= UInt64(data[offset])}
                }
            }
            print("BENCH \(mode) 900 frames/30 simulated seconds wall_s=\(ProcessInfo.processInfo.systemUptime-start) cpu_s=\(Double(clock()-cpu)/Double(CLOCKS_PER_SEC)) checksum=\(checksum)")
            print("CACHE bytes=\(view.idleCacheBytes) count=\(view.idleCacheCount)")
            return
        }
        view.update(CatPose(breath:0.25));_ = capture(view)
        let first=view.renderedCatImage!
        view.update(CatPose(breath:0.75));_ = capture(view)
        view.update(CatPose(breath:0.25));_ = capture(view)
        precondition(view.renderedCatImage === first,"revisited idle frame must reuse its original bitmap")
        // Real bitmaps, hard byte accounting, LRU eviction, duplicate replacement,
        // oversized rejection, finite key domain and scale invalidation.
        let space=CGColorSpace(name:CGColorSpace.sRGB)!
        let small=CGContext(data:nil,width:2,height:2,bitsPerComponent:8,bytesPerRow:8,space:space,
                            bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
        let large=CGContext(data:nil,width:4,height:4,bitsPerComponent:8,bytesPerRow:16,space:space,
                            bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
        let budget=CatIdleFrameCache(byteLimit:32)
        budget.prepare(scale:1);budget.insert(small,for:0);budget.insert(small,for:1)
        check(budget.byteCount==32 && budget.count==2,"exact bitmap byte accounting")
        _ = budget.image(for:0);budget.insert(small,for:2)
        check(budget.image(for:1)==nil && budget.image(for:0) != nil,"evict least recently used only")
        budget.insert(small,for:0)
        check(budget.byteCount==32,"replacement must not double count")
        budget.insert(large,for:3)
        check(budget.byteCount==32 && budget.image(for:3)==nil,"oversized frame must not enter cache")
        budget.insert(small,for:49)
        check(budget.image(for:49)==nil,"idle key domain is bounded")
        budget.prepare(scale:2)
        check(budget.byteCount==0 && budget.count==0,"scale change releases previous namespace")
        var poses=(0...48).map{CatPose(breath:Double($0)/48)}
        poses += poses.reversed()
        poses += [CatPose(eyes:0.5,breath:0.25),CatPose(breath:0.25,lean:1),
                  CatPose(breath:0.25,leftEar:0.4),CatPose(breath:0.25,head:0.6),
                  CatPose(breath:0.25,lookX:0.5),CatPose(breath:0.25)]
        for gesture in [MouthGesture.tongueTip,.noseLick] {
            poses.append(CatPose(breath:0.25,mouth:CatMouth.pose(gesture,elapsed:0.35)))
            poses.append(CatPose(breath:0.25))
        }
        #if CAT_PAW_EXPERIMENT
        poses.append(CatPose(breath:0.25,paw:PawPose(raise:0.5)))
        poses.append(CatPose(breath:0.25,groomingProfile:true))
        poses.append(CatPose(breath:0.25))
        #endif
        for width in [290.0,440.0,200.0,290.0] {
            size(width)
            for (index,pose) in poses.enumerated() {
                autoreleasepool {
                    view.update(pose);old.update(pose)
                    precondition(capture(view) == capture(old),"build34 pixels changed width \(width) pose \(index)")
                    check(view.idleCacheBytes<=64*1024*1024 && view.idleCacheCount<=49,"view cache exceeds budget")
                }
            }
        }
        view.viewDidChangeBackingProperties()
        check(view.idleCacheBytes==0 && view.idleCacheCount==0,"backing change invalidates idle frames")
        view.update(CatPose(breath:0.5));old.update(CatPose(breath:0.5))
        view.mouthPose=MouthPose(extensionAmount:0.6);old.mouthPose=view.mouthPose
        check(capture(view)==capture(old) && view.idleCacheCount==0,"independent mouth must bypass idle storage")
        view.mouthPose=MouthPose();old.mouthPose=MouthPose()
        #if CAT_PAW_EXPERIMENT
        view.pawPose=PawPose(raise:0.6);old.pawPose=view.pawPose
        check(capture(view)==capture(old) && view.idleCacheCount==0,"independent paw must bypass idle storage")
        view.pawPose=PawPose();old.pawPose=PawPose()
        #endif
        var toy=CatToyFrame();toy.opacity=1
        view.toyFrame=toy;old.toyFrame=toy
        view.update(CatPose(breath:0.75));old.update(CatPose(breath:0.75))
        check(capture(view)==capture(old) && view.idleCacheCount>0,"Static ball must preserve identical pixels while reusing the cat-only idle cache")
        view.toyFrame=CatToyFrame();old.toyFrame=CatToyFrame()
        view.useV1Rendering=true;old.useV1Rendering=true
        check(capture(view)==capture(old),"V1 path changed")
        view.useV1Rendering=false;old.useV1Rendering=false
        check(capture(view)==capture(old),"return from V1 changed")
        for state in [(true,false),(false,true),(false,false)] {
            var motion=CatMotion(now:0,seed:42);motion.pet(0)
            for i in 0..<24 {
                autoreleasepool {
                    let pose=motion.frame(Double(i)/30,reduced:state.0,paused:state.1)
                    view.update(pose);old.update(pose)
                    check(capture(view)==capture(old),"reduced/pause/resume pixels differ")
                }
            }
        }
        view.cacheEnabled=false
        view.update(CatPose(breath:0.25));_ = capture(view);let uncached=view.renderedCatImage!
        view.update(CatPose(breath:0.75));_ = capture(view)
        view.update(CatPose(breath:0.25));_ = capture(view)
        check(view.renderedCatImage !== uncached,"cacheEnabled=false must bypass both caches")
        print("PASS idle cache: A-B-A bitmap reuse and exact build34 RGBA across sizes and interaction transitions")
    }
}
