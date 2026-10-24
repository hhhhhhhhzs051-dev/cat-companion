import AppKit
import CoreImage

@main struct EyeVariationTests {
    static func check(_ value:Bool,_ message:String) {
        guard value else{fputs("FAIL eye variation: \(message)\n",stderr);exit(1)}
    }
    static func main() throws {
        _=NSApplication.shared
        let out=URL(fileURLWithPath:CommandLine.arguments[1])
        let context=CIContext(options:[.workingColorSpace:NSNull(),.outputColorSpace:NSNull(),
            .workingFormat:CIFormat.RGBAf.rawValue,.cacheIntermediates:false])
        let ramp=CIColorKernel(source:"kernel vec4 coordinates(){vec2 p=destCoord()/1254.0;return vec4(p.x,p.y,0.,1.);}")!
            .apply(extent:CGRect(x:0,y:0,width:1254,height:1254),arguments:[])!
        let renderer=EyeVariationRenderer()
        func sample(_ state:EyeVariation,_ x:Int,_ y:Int)->CGPoint {
            var result=[Float](repeating:0,count:4)
            result.withUnsafeMutableBytes {context.render(renderer.apply(to:ramp,state:state),toBitmap:$0.baseAddress!,
                rowBytes:16,bounds:CGRect(x:x,y:1253-y,width:1,height:1),format:.RGBAf,colorSpace:nil)}
            return CGPoint(x:Double(result[0])*1254,y:1254-Double(result[1])*1254)
        }
        check(EyeVariation(direction:.nan,gain:.infinity,pupilWidth:.nan) == .neutral,"nonfinite inputs neutral")
        check(EyeVariation(direction:1,pupilWidth:1.25).direction == 0,"pupil study never combines gaze")
        for gain in [1.125,1.35,1.5] {for direction in [-1.0,1.0] {
            for (x,shift) in [(688,4.0),(880,3.0)] {
                for y in [544,550,556] {
                    let p=sample(EyeVariation(direction:direction,gain:gain),x,y)
                    check(abs(p.x-(Double(x)+0.5-direction*gain*shift))<0.02,
                          "gaze must rigidly translate at gain \(gain): \(p)")
                    check(abs(p.y-(Double(y)+0.5))<0.02,"no vertical displacement")
                }
            }
        }}
        print("PASS GPU rigid source-coordinate probes for both eyes and all gaze presets")
        for width in [1.15,1.25,1.4] {
            let state=EyeVariation(pupilWidth:width)
            for (x,y) in [(687,549),(883,549)] {
                let p=sample(state,x,y)
                check(abs(p.x-(Double(x)+0.5))>0.12,"pupil-width study must actually change original sampling")
                check(abs(p.y-(Double(y)+0.5))<0.02,"pupil height must remain original")
            }
            for y in 540...558 {
                for range in [670...711,862...906] {
                    var last = -Double.infinity
                    for x in range {
                        let p=sample(state,x,y)
                        check(p.x>last,"pupil mapping must not fold at \(x),\(y)")
                        last=p.x
                    }
                }
            }
        }
        print("PASS bounded, nonfolding pupil-width maps with original height")
        let wideSample=sample(EyeVariation(pupilWidth:1.4),687,549)
        let mildSample=sample(EyeVariation(pupilWidth:1.25),687,549)
        check(abs(wideSample.x-688.57143)<0.02 && wideSample.x-mildSample.x>0.25,
              "40 percent shader must use wider sampling than the 25 percent reference")
        let raw=CIImage(contentsOf:URL(fileURLWithPath:"src/assets/cat-d.png"))!
        let ci=CIContext(options:[.cacheIntermediates:false])
        func bitmap(_ image:CIImage)->NSBitmapImageRep {NSBitmapImageRep(cgImage:ci.createCGImage(image,from:raw.extent)!)}
        let original=bitmap(raw)
        let mildImage=bitmap(renderer.apply(to:raw,state:EyeVariation(pupilWidth:1.25)))
        let wideImage=bitmap(renderer.apply(to:raw,state:EyeVariation(pupilWidth:1.4)))
        check(Data(bytes:mildImage.bitmapData!,count:mildImage.bytesPerRow*mildImage.pixelsHigh)
            != Data(bytes:wideImage.bitmapData!,count:wideImage.bytesPerRow*wideImage.pixelsHigh),
              "two selectable pupil strengths must produce distinct pixels")
        let cases:[(String,EyeVariation)]=[("neutral",.neutral),
            ("62-left",EyeVariation(direction:-1)),("62-right",EyeVariation(direction:1)),
            ("gaze20-left",EyeVariation(direction:-1,gain:1.35)),("gaze20-right",EyeVariation(direction:1,gain:1.35)),
            ("gaze33-left",EyeVariation(direction:-1,gain:1.5)),("gaze33-right",EyeVariation(direction:1,gain:1.5)),
            ("pupil15",EyeVariation(pupilWidth:1.15)),("pupil25",EyeVariation(pupilWidth:1.25)),
            ("pupil40",EyeVariation(pupilWidth:1.4))]
        for (name,state) in cases {
            let b=bitmap(renderer.apply(to:raw,state:state))
            if name.hasPrefix("62") {
                let accepted=bitmap(CatEyeGazeRenderer().apply(to:raw,aim:CatEyeAim(x:state.direction,gain:1.125)))
                check(Data(bytes:b.bitmapData!,count:b.bytesPerRow*b.pixelsHigh)==Data(bytes:accepted.bitmapData!,count:accepted.bytesPerRow*accepted.pixelsHigh),"62 reference must be byte-identical")
            }
            var changed=0
            for y in 0..<1254 {for x in 0..<1254 {
                let inside=(649...729).contains(x) && (525...585).contains(y)
                    || (845...919).contains(x) && (525...585).contains(y)
                let a=original.bitmapData!+y*original.bytesPerRow+x*4,c=b.bitmapData!+y*b.bytesPerRow+x*4
                if (0..<4).contains(where:{a[$0] != c[$0]}) {
                    changed+=1;check(inside,"outside-eye pixels changed: \(name) \(x),\(y)")
                }
            }}
            check(state == .neutral ? changed==0:changed>20,"expected localized changes \(name)")
            if state.direction != 0 {
                for (range,offset) in [(679..<701,4.0),(871..<891,3.0)] {
                    let translated=bitmap(raw.transformed(by:CGAffineTransform(translationX:state.direction*state.gain*offset,y:0)))
                    for y in 539..<556 {for x in range {
                        let e=translated.bitmapData!+y*translated.bytesPerRow+x*4,a=b.bitmapData!+y*b.bytesPerRow+x*4
                        func dark(_ p:UnsafeMutablePointer<UInt8>)->Bool {p[0]<77 && p[1]<72 && p[2]<47}
                        check(dark(e)==dark(a),"old/new pupil silhouette mismatch \(name) \(x),\(y)")
                    }}
                }
            }
            for (x,y) in [(674,529),(682,531),(690,533),(699,536),(700,536),(709,539),
                          (870,531),(872,532),(878,528),(886,526),(902,524)] {
                let a=original.bitmapData!+y*original.bytesPerRow+x*4,c=b.bitmapData!+y*b.bytesPerRow+x*4
                check((0..<4).allSatisfy{a[$0]==c[$0]},"eyelid landmark changed \(name) \(x),\(y)")
            }
            let crop=b.cgImage!.cropping(to:CGRect(x:620,y:510,width:330,height:90))!
            try NSBitmapImageRep(cgImage:crop).representation(using:.png,properties:[:])!.write(to:out.appendingPathComponent("eyes-\(name).png"))
        }
        print("PASS original neutral, exact62 reference, unchanged outer eye/lid landmarks; diagnostic images exported")
        let view=try NativeCatView(resources:URL(fileURLWithPath:"src"))
        let baseline=try NativeCatView(resources:URL(fileURLWithPath:"src"))
        for v in [view,baseline] {v.frame=NSRect(x:0,y:0,width:290,height:267)}
        func render(_ v:NativeCatView)->NSBitmapImageRep {
            let b=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:580,pixelsHigh:534,bitsPerSample:8,
                samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
            b.size=v.bounds.size;v.cacheDisplay(in:v.bounds,to:b);return b
        }
        func data(_ b:NSBitmapImageRep)->Data {Data(bytes:b.bitmapData!,count:b.bytesPerRow*b.pixelsHigh)}
        let nativeOriginal=render(baseline)
        for (name,state) in cases {
            view.eyeVariation=state;view.update(CatPose())
            let b=render(view)
            for y in 0..<534 {for x in 0..<580 {
                let p=CGPoint(x:Double(x)/2,y:Double(y)/2)
                if !CGRect(x:147,y:126,width:22,height:18).contains(p) && !CGRect(x:184,y:126,width:22,height:18).contains(p) {
                    let a=nativeOriginal.bitmapData!+y*nativeOriginal.bytesPerRow+x*4,c=b.bitmapData!+y*b.bytesPerRow+x*4
                    check((0..<4).allSatisfy{a[$0]==c[$0]},"native outside-eye pixels changed \(name)")
                }
            }}
            try b.representation(using:.png,properties:[:])!.write(to:out.appendingPathComponent("native-\(name).png"))
            baseline.eyeAim=CatEyeAim(x:state.direction,gain:1.125)
            if name.hasPrefix("62") || state == .neutral {check(data(b)==data(render(baseline)),"native62/neutral exact")}
            baseline.eyeAim = .neutral
            for closure in [0.0,0.3,0.7,0.93359375,1.0] {
                view.update(CatPose(eyes:closure));baseline.update(CatPose(eyes:closure))
                if closure>=0.93 {check(data(render(view))==data(render(baseline)),"late/full closed exact")}
            }
            let count=view.catRasterizations
            for _ in 0..<8 {_=render(view)}
            check(view.catRasterizations==count,"unchanged full-closed cache must remain bounded")
            var grooming=CatPose(eyes:0.4);grooming.groomingProfile=true
            view.update(grooming);baseline.update(grooming)
            check(data(render(view))==data(render(baseline)),"grooming ignores experimental eyes")
            view.useV1Rendering=true;baseline.useV1Rendering=true
            check(data(render(view))==data(render(baseline)),"V1 ignores experimental eyes")
            view.useV1Rendering=false;baseline.useV1Rendering=false
            view.update(CatPose());baseline.update(CatPose());_=render(view);_=render(baseline)
            for y in stride(from:0.0,through:267,by:7) {for x in stride(from:0.0,through:290,by:7) {
                check(view.touchRegion(CGPoint(x:x,y:y))==baseline.touchRegion(CGPoint(x:x,y:y)),"hit geometry unchanged")
            }}
        }
        view.eyeVariation = .neutral
        check(data(render(view))==data(nativeOriginal),"return neutral restores exact original")
        print("PASS 290pt native62 identity, localized changes, closure/cache/V1/grooming and hit-grid checks")
    }
}
