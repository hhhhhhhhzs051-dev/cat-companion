import AppKit
import CoreImage

@main struct EyeGazeTests {
    static func check(_ condition: Bool, _ message: String) {
        if !condition { fputs("FAIL eye gaze: \(message)\n", stderr); exit(1) }
    }
    static func bitmap(_ view: NSView) -> NSBitmapImageRep {
        let b = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:Int(view.bounds.width*2),
            pixelsHigh:Int(view.bounds.height*2),bitsPerSample:8,samplesPerPixel:4,
            hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        b.size=view.bounds.size;view.cacheDisplay(in:view.bounds,to:b);return b
    }
    static func bytes(_ view: NSView) -> Data {
        let b=bitmap(view);return Data(bytes:b.bitmapData!,count:b.bytesPerRow*b.pixelsHigh)
    }
    static func checkRigidEyeInterior() {
        // Probe the real renderer with coordinates. A fixed eye rim alone did
        // not prevent the rejected warp from bending the top of a pupil.
        let image=CIColorKernel(source:"kernel vec4 coordinates() {vec2 p=destCoord()/1254.0;return vec4(p.x,p.y,0.0,1.0);}")!
            .apply(extent:CGRect(x:0,y:0,width:1254,height:1254),arguments:[])!
        let context=CIContext(options:[.workingColorSpace:NSNull(),.outputColorSpace:NSNull(),
                                       .workingFormat:CIFormat.RGBAf.rawValue,.cacheIntermediates:false])
        for aim in [-1.0,1.0] {
            let result=CatEyeGazeRenderer().apply(to:image,aim:CatEyeAim(x:aim))
            var pixels=[Float](repeating:0,count:270*60*4)
            pixels.withUnsafeMutableBytes {
                context.render(result,toBitmap:$0.baseAddress!,rowBytes:270*16,
                    bounds:CGRect(x:640,y:674,width:270,height:60),format:.RGBAf,colorSpace:nil)
            }
            func offset(_ x:Int,_ y:Int)->CGPoint {
                let i=((y-520)*270+(x-640))*4
                return CGPoint(x:Double(pixels[i])*1254-(Double(x)+0.5),
                               y:Double(pixels[i+1])*1254-(1254-Double(y)-0.5))
            }
            // Hand-checked visible iris samples above/below the pupil centre.
            // Each pair must travel together, not just share a centroid sign.
            for (x,upper,lower) in [(688,540,550),(880,539,550)] {
                let a=offset(x,upper),b=offset(x,lower)
                check(abs(a.x-b.x)<0.025 && abs(a.y)<0.025 && abs(b.y)<0.025,
                      "unoccluded pupil/iris must translate rigidly: \(a) vs \(b), aim \(aim)")
                check(abs(a.x)>=2 && abs(a.x)<=5.5,
                      "static horizontal eye study must keep a small genuine translation: \(a) at \(x), aim \(aim)")
            }
        }
        print("PASS actual eye interior translates together without upper/lower shear")
    }
    static func main() throws {
        _=NSApplication.shared
        let out=URL(fileURLWithPath:CommandLine.arguments[1])
        let candidate=try NativeCatView(resources:URL(fileURLWithPath:"src"))
        let baseline=try Build61NativeCatView(resources:URL(fileURLWithPath:"src"))
        for v in [candidate as NSView,baseline as NSView] {v.frame=NSRect(x:0,y:0,width:290,height:267)}
        check(CatEyeAim(x:.infinity,y:.nan) == .neutral,"nonfinite input must fail neutral")
        check(CatEyeAim(x:99,y:-99) == CatEyeAim(x:1,y:-1),"unbounded targets must clamp")
        checkRigidEyeInterior()
        for p in [CatPose(),CatPose(eyes:0.4),CatPose(eyes:1,breath:0.5,leftEar:0.8,rightEar:0.3,head:0.5),
                  CatPose(breath:0.3,lookX:-0.4)] {
            candidate.update(p);baseline.update(p)
            check(bytes(candidate)==bytes(baseline),"neutral aim must be byte-identical to accepted61")
        }
        candidate.update(CatPose());baseline.update(CatPose())
        let neutral=bytes(baseline)
        // AppKit pads each bitmap row (2336 here, not width*4 == 2320).
        // Never interpret that padding as the beginning of the next image row.
        let nativeRowBytes=bitmap(baseline).bytesPerRow
        candidate.eyeAim=CatEyeAim(x:1,y:0)
        let right=bytes(candidate)
        try bitmap(candidate).representation(using:.png,properties:[:])!.write(to:out.appendingPathComponent("native-right.png"))
        try bitmap(baseline).representation(using:.png,properties:[:])!.write(to:out.appendingPathComponent("native-original.png"))
        check(right != neutral,"right target must move eye texture independently of the head")
        check(candidate.pose==CatPose(),"eye aim must never change head, body, ears or closure")
        var outsideCount=0,firstOutside=""
        for y in 0..<534 {for x in 0..<580 {
            // Native transform hand checked: (source.x+135)*290/1525,
            // 60+(source.y-165)*290/1525; allow the resampling footprint.
            let p=CGPoint(x:Double(x)/2,y:Double(y)/2)
            let inEyes=CGRect(x:147,y:126,width:22,height:18).contains(p)
                || CGRect(x:184,y:126,width:22,height:18).contains(p)
            if !inEyes {
                let index=y*nativeRowBytes+x*4
                if right[index..<index+4] != neutral[index..<index+4] {
                    outsideCount+=1
                    if firstOutside.isEmpty {firstOutside="(\(x),\(y)) \(Array(neutral[index..<index+4])) -> \(Array(right[index..<index+4]))"}
                }
            }
        }}
        check(outsideCount==0,"native 290pt eye aim altered \(outsideCount) pixels outside eye bounds; first \(firstOutside)")
        print("PASS neutral accepted61 pixel identity and independent eye movement")
        let ci=CIContext(options:[.cacheIntermediates:false])
        let raw=CIImage(contentsOf:URL(fileURLWithPath:"src/assets/cat-d.png"))!
        let renderer=CatEyeGazeRenderer()
        var rawImages:[String:NSBitmapImageRep]=[:]
        for (name,aim) in [("neutral",CatEyeAim.neutral),("right",CatEyeAim(x:1)),
                           ("left",CatEyeAim(x:-1))] {
            let image=renderer.apply(to:raw,aim:aim)
            let cg=ci.createCGImage(image,from:raw.extent)!
            let b=NSBitmapImageRep(cgImage:cg);rawImages[name]=b
            // Magnification is diagnostic only; the interactive study is 290pt.
            let crop=cg.cropping(to:CGRect(x:620,y:510,width:330,height:90))!
            try NSBitmapImageRep(cgImage:crop).representation(using:.png,properties:[:])!
                .write(to:out.appendingPathComponent("eyes-\(name).png"))
        }
        func centroid(_ b:NSBitmapImageRep,_ r:CGRect)->CGPoint {
            var count=0.0,sx=0.0,sy=0.0
            for y in Int(r.minY)..<Int(r.maxY) {for x in Int(r.minX)..<Int(r.maxX) {
                let c=b.colorAt(x:x,y:y)!.usingColorSpace(.deviceRGB)!
                // Hand-picked pupil interior; excludes the dark upper rim.
                if c.redComponent<0.30 && c.greenComponent<0.28 && c.blueComponent<0.18 {
                    count+=1;sx+=Double(x);sy+=Double(y)
                }
            }}
            check(count>12,"pupil detector must find real original texture")
            return CGPoint(x:sx/count,y:sy/count)
        }
        for r in [CGRect(x:670,y:540,width:40,height:22),CGRect(x:863,y:539,width:34,height:22)] {
            let base=centroid(rawImages["neutral"]!,r)
            let right=centroid(rawImages["right"]!,r),left=centroid(rawImages["left"]!,r)
            check(right.x>base.x+1.5 && left.x<base.x-1.5,"both pupils must actually move in the requested screen direction")
            // The user now prioritizes unchanged shape over the rejected
            // >1.1pt visibility floor. Keep movement real but deliberately small.
            let shifts=[right.x-base.x,base.x-left.x].map{$0*290/1525}
            check(shifts.allSatisfy{$0>=0.45 && $0<=1.1},
                  "290pt pupil displacement must stay small (0.45...1.1pt), got \(shifts)")
            check(abs(right.y-base.y)<1.5 && abs(left.y-base.y)<1.5,
                  "either horizontal aim must not make one pupil jump vertically")
            print("Pupil centroid: base \(base), left \(left), right \(right)")
        }
        for (name,b) in rawImages where name != "neutral" {
            let base=rawImages["neutral"]!
            // Regression: the old aperture left an unmoved dark pupil segment
            // at y539..541 even though all deeper interior probes passed.
            for (x,y,shift) in [(693,540,-4),(694,540,-4),(875,540,3),(876,540,3),
                                (695,537,-4),(875,533,3)] {
                guard (shift<0 && name=="left") || (shift>0 && name=="right") else{continue}
                let expected=base.bitmapData!.advanced(by:y*base.bytesPerRow+(x-shift)*4)
                let actual=b.bitmapData!.advanced(by:y*b.bytesPerRow+x*4)
                check((0..<4).allSatisfy{abs(Int(expected[$0])-Int(actual[$0]))<=1},
                      "old upper pupil must not remain at its original position (\(name), \(x), \(y))")
            }
            // Hand-checked ink/eyelid landmarks above the visible iris must
            // stay fixed, even when sampling closer to the source's edge.
            for (x,y) in [(674,529),(682,531),(690,533),(699,536),(700,536),(709,539),
                          (870,531),(872,532),(878,528),(886,526),(902,524),
                          (678,530),(680,531),(697,535),(702,536),(706,538),
                          (874,531),(888,527),(890,526)] {
                let original=base.bitmapData!.advanced(by:y*base.bytesPerRow+x*4)
                let actual=b.bitmapData!.advanced(by:y*b.bytesPerRow+x*4)
                check((0..<4).allSatisfy{original[$0]==actual[$0]},
                      "original upper eyelid/ink landmark must stay fixed (\(name), \(x), \(y))")
            }
            // Expanding upper source coverage must not also admit lower-lid
            // texels. These points remain original for the named direction.
            for (direction,x,y) in [("right",705,571),("right",706,571),("left",721,565)]
                where direction == name {
                let original=base.bitmapData!.advanced(by:y*base.bytesPerRow+x*4)
                let actual=b.bitmapData!.advanced(by:y*b.bytesPerRow+x*4)
                check((0..<4).allSatisfy{original[$0]==actual[$0]},
                      "upper-edge correction must preserve lower-lid exclusion (\(name), \(x), \(y))")
            }
            for (range,shift) in [(679..<701,4),(871..<891,3)] {
                let dx=name=="right" ? shift:-shift
                for y in 539..<556 {for x in range {
                    let expected=base.bitmapData!.advanced(by:y*base.bytesPerRow+(x-dx)*4)
                    let actual=b.bitmapData!.advanced(by:y*b.bytesPerRow+x*4)
                    // Compare the visible pupil silhouette across whole rows,
                    // including BOTH vacated and newly occupied locations.
                    func dark(_ c:UnsafeMutablePointer<UInt8>)->Bool {c[0]<77 && c[1]<72 && c[2]<47}
                    check(dark(expected)==dark(actual),
                          "visible upper pupil silhouette must translate without old fragments (\(name), \(x), \(y))")
                }}
            }
            // Pixel-for-pixel translated patches (including pupil + iris), not
            // only centroid or a coordinate ramp. These are hand-checked
            // unoccluded interior rectangles for both allowed directions.
            for (r,shift) in [(CGRect(x:682,y:543,width:13,height:18),4),
                              (CGRect(x:875,y:544,width:12,height:15),3)] {
                let dx=name == "right" ? shift:-shift
                for y in Int(r.minY)..<Int(r.maxY) {for x in Int(r.minX)..<Int(r.maxX) {
                    let a=base.bitmapData!.advanced(by:y*base.bytesPerRow+(x-dx)*4)
                    let c=b.bitmapData!.advanced(by:y*b.bytesPerRow+x*4)
                    check((0..<4).allSatisfy{abs(Int(a[$0])-Int(c[$0]))<=1},
                          "unoccluded original pupil/iris must keep its exact texture and shape (\(name), \(x), \(y))")
                }}
            }
            for y in 0..<1254 {for x in 0..<1254 {
                let inEye=CGRect(x:649,y:525,width:80,height:60).contains(CGPoint(x:x,y:y))
                    || CGRect(x:845,y:525,width:74,height:60).contains(CGPoint(x:x,y:y))
                let a=base.bitmapData!.advanced(by:y*base.bytesPerRow+x*4)
                let c=b.bitmapData!.advanced(by:y*b.bytesPerRow+x*4)
                if inEye {
                    // Everywhere in the aperture, choose only a complete
                    // original texel or an integer-translated original texel.
                    // No squeezed/crossfaded pupil, duplicated generated fill,
                    // or new colour is permitted by this static experiment.
                    let dx=(x<790 ? 4:3)*(name == "right" ? 1:-1)
                    let translated=base.bitmapData!.advanced(by:y*base.bytesPerRow+(x-dx)*4)
                    let unchanged=(0..<4).allSatisfy{abs(Int(a[$0])-Int(c[$0]))<=1}
                    let moved=(0..<4).allSatisfy{abs(Int(translated[$0])-Int(c[$0]))<=1}
                    check(unchanged || moved,
                          "eye texture must be original or rigidly translated, never distorted (\(name), \(x), \(y))")
                } else {
                    check(a[0]==c[0] && a[1]==c[1] && a[2]==c[2] && a[3]==c[3],"eye-only mapping must not alter pixels outside calibrated eye ROI (\(name), \(x), \(y))")
                }
            }}
        }
        print("PASS original iris/pupil interior pixels preserved under rigid translation")
        for closure in [0.0,0.3,0.7,1.0] {
            candidate.eyeAim=CatEyeAim(x:1,y:1)
            candidate.update(CatPose(eyes:closure))
            baseline.update(CatPose(eyes:closure))
            if closure==1 {check(bytes(candidate)==bytes(baseline),"fully closed endpoint must ignore gaze and preserve exact original lids")}
            let b=bitmap(candidate)
            try b.representation(using:.png,properties:[:])!.write(to:out.appendingPathComponent("normal-closure-\(closure).png"))
        }
        let heldCount=candidate.catRasterizations
        candidate.eyeAim=CatEyeAim(x:-1,y:-1);_=bytes(candidate)
        check(candidate.catRasterizations==heldCount,"hidden pupil changes cannot churn the full-closed cache")
        for closure in [0.93359375,0.99609375] {
            candidate.update(CatPose(eyes:closure));baseline.update(CatPose(eyes:closure))
            check(bytes(candidate)==bytes(baseline),"last eyelid closing segment must use only accepted pixels")
        }
        var groom=CatPose(eyes:0.4);groom.groomingProfile=true
        candidate.update(groom);baseline.update(groom)
        check(bytes(candidate)==bytes(baseline),"special grooming eyes must not receive new eye textures")
        candidate.useV1Rendering=true;baseline.useV1Rendering=true
        candidate.update(CatPose());baseline.update(CatPose())
        check(bytes(candidate)==bytes(baseline),"legacy V1 ignores new eye textures")
        candidate.useV1Rendering=false;baseline.useV1Rendering=false
        for y in stride(from:0.0,through:267,by:7) {for x in stride(from:0.0,through:290,by:7) {
            check(candidate.touchRegion(CGPoint(x:x,y:y))==baseline.touchRegion(CGPoint(x:x,y:y)),"eye texture cannot change hit geometry")
        }}
        candidate.update(CatPose());candidate.eyeAim = .neutral
        check(bytes(candidate)==neutral,"return to neutral must restore original pixels after nonzero and closed states")
        let idleCount=candidate.catRasterizations
        for _ in 0..<10 {_=bytes(candidate)}
        check(candidate.catRasterizations==idleCount,"static study does not keep rasterizing unchanged eyes")
        print("PASS coordinated pupils, fixed outer pixels, closed endpoint/cache, hit geometry and neutral return")
    }
}
