import AppKit
import CoreImage

@main struct ContinuousGazeRenderTests {
    static func check(_ ok:Bool,_ message:String) {if !ok {print("FAIL continuous pixels: \(message)");exit(1)}}
    static func bitmap(_ v:NSView)->NSBitmapImageRep {
        let b=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:580,pixelsHigh:534,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        b.size=v.bounds.size;v.cacheDisplay(in:v.bounds,to:b);return b
    }
    static func data(_ b:NSBitmapImageRep)->Data {Data(bytes:b.bitmapData!,count:b.bytesPerRow*b.pixelsHigh)}
    static func main() throws {
        _=NSApplication.shared
        let out=URL(fileURLWithPath:CommandLine.arguments[1])
        let baseline=try NativeCatView(resources:URL(fileURLWithPath:"src")),view=try NativeCatView(resources:URL(fileURLWithPath:"src"))
        baseline.frame=NSRect(x:0,y:0,width:290,height:267);view.frame=baseline.frame
        let ramp=CIColorKernel(source:"kernel vec4 coordinates() {vec2 p=destCoord()/1254.0;return vec4(p.x,p.y,0.0,1.0);}")!.apply(extent:CGRect(x:0,y:0,width:1254,height:1254),arguments:[])!
        let context=CIContext(options:[.workingColorSpace:NSNull(),.outputColorSpace:NSNull(),.workingFormat:CIFormat.RGBAf.rawValue,.cacheIntermediates:false])
        let renderer=CatEyeGazeRenderer()
        check(CatEyeAim(x:0,gain:1.125) == .neutral,"enhanced neutral is canonical for cache/return")
        check(CatEyeAim(x:1,gain:100).gain==1 && CatEyeAim(x:1,gain:.nan).gain==1,"invalid gain cannot increase range")
        var endpoints:[Data]=[]
        #if CAT_EYE_INTERACTION_PREVIEW || CAT_EYE_INTERACTION
        let gains=[1.125,1.5]
        #else
        let gains=[1.0,1.125]
        #endif
        for gain in gains {
            for direction in [-1.0,1.0] {
                let result=renderer.apply(to:ramp,aim:CatEyeAim(x:direction,fixedApertureX:direction,gain:gain))
                var pixels=[Float](repeating:0,count:270*60*4)
                pixels.withUnsafeMutableBytes {context.render(result,toBitmap:$0.baseAddress!,rowBytes:270*16,bounds:CGRect(x:640,y:674,width:270,height:60),format:.RGBAf,colorSpace:nil)}
                for (x,y,shift) in [(688,540,4.0),(688,550,4),(880,539,3),(880,550,3)] {
                    let i=((y-520)*270+x-640)*4
                    let dx=Double(pixels[i])*1254-(Double(x)+0.5),dy=Double(pixels[i+1])*1254-(1254-Double(y)-0.5)
                    check(abs(dx+shift*direction*gain)<0.025 && abs(dy)<0.025,"both pupil heights translate rigidly at selected gain")
                }
            }
            var gaze=CatAccessoryGaze();_=gaze.tap(at:0,allowed:true)
            for frame in 0...90 {
                let t=Double(frame)/30
                if [6,20,33,43].contains(frame) {_=gaze.tap(at:t,allowed:true)}
                let response=gaze.sample(at:t,allowed:true)
                for closure in [0.0,0.4,0.92,1.0] {
                    var pose=CatPose(eyes:closure,breath:0.35)
                    pose.lookX=response.lookX;pose.rightEar=response.rightEar
                    baseline.update(pose);view.update(pose)
                    view.eyeAim=CatEyeAim(x:response.eye,fixedApertureX:1,gain:gain)
                    let a=data(bitmap(baseline)),image=bitmap(view),b=data(image)
                    check(view.pose==baseline.pose,"gain cannot change head/body/ear/eyelid pose")
                    if closure==1 || response.eye==0 {check(a==b,"fully closed/neutral stays pixel exact")}
                    for y in 0..<534 {for x in 0..<580 {
                        let p=CGPoint(x:Double(x)/2,y:Double(y)/2)
                        if !CGRect(x:146,y:124,width:25,height:23).contains(p) && !CGRect(x:183,y:124,width:26,height:23).contains(p) {
                            let i=y*image.bytesPerRow+x*4
                            check(a[i..<i+4]==b[i..<i+4],"non-eye pixels changed")
                        }
                    }}
                    if closure==0 && [0,15,38,56,90].contains(frame) {
                        try image.representation(using:.png,properties:[:])!.write(to:out.appendingPathComponent("gain-\(gain)-frame-\(frame)-290pt.png"))
                        if frame==15 {endpoints.append(b)}
                    }
                }
            }
            check(!gaze.isActive,"repeated input settles by end of sample")
            view.update(CatPose())
            var previous:Data?,largest=0
            for step in 0...256 {
                view.eyeAim=CatEyeAim(x:Double(step)/256,fixedApertureX:1,gain:gain)
                let image=bitmap(view),b=data(image)
                if let previous {
                    for y in 248..<294 {for x in 292..<418 {
                        let i=y*image.bytesPerRow+x*4
                        for c in 0..<3 {largest=max(largest,abs(Int(b[i+c])-Int(previous[i+c])))}
                    }}
                }
                previous=b
            }
            print("METRIC gain \(gain) fixed-aperture fine-step max \(largest)/255")
            check(largest<=5,"fine movement must not toggle an eye-edge patch")
        }
        check(endpoints.count==2 && endpoints[0] != endpoints[1],"A/B must change actual rendered eyes, not only menu labels")
        print("PASS 728 integrated renders, calibrated rigid translation at \(gains), no non-eye changes, exact closed/neutral, fine-step seams and real A/B difference")
    }
}
