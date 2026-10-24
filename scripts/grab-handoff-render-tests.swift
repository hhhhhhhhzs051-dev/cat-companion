import AppKit

@main struct GrabHandoffPixels {
    static func main() throws {
        _=NSApplication.shared
        func check(_ ok:Bool,_ message:String) {if !ok {print("FAIL grab pixels: \(message)");exit(1)}}
        let view=try NativeCatView(resources:URL(fileURLWithPath:"src"))
        view.frame=NSRect(x:0,y:0,width:290,height:267)
        func render(_ eye:Double,_ width:Double,_ closed:Double=0)->Data {
            view.update(CatPose(eyes:closed))
            view.eyeAim=CatEyeAim(x:eye,fixedApertureX:1,gain:1.5)
            view.eyeVariation=EyeVariation(pupilWidth:width,fixedAperture:true,pupilLimit:1.5)
            let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:580,pixelsHigh:534,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:580*4,bitsPerPixel:0)!
            bitmap.size=view.bounds.size;view.cacheDisplay(in:view.bounds,to:bitmap)
            return Data(bytes:bitmap.bitmapData!,count:bitmap.bytesPerRow*bitmap.pixelsHigh)
        }
        let neutral=render(0,1),closed=render(0,1,1),acceptedPupil=render(0,1.5)
        for fromWidth in [1.0,1.3,1.5] {
            var prior=render(1,fromWidth),maxStep=0
            var remainder=CatGrabHandoff()
            remainder.begin(lookX:0.28,rightEar:0.18,eye:1,at:0)
            for frame in 0...21 {
                let t=Double(frame)/30,phase=min(1,t/0.7)
                let width=fromWidth+(1.5-fromWidth)*phase*phase*(3-2*phase)
                let eye=remainder.sample(at:t).eye,data=render(eye,width)
                if CommandLine.arguments.count>1 {
                    try data.write(to:URL(fileURLWithPath:CommandLine.arguments[1]).appendingPathComponent("width-\(fromWidth)-frame-\(frame).rgba"))
                }
                check(render(eye,width,1)==closed,"fully closed eye composition remains exact")
                for y in 0..<534 {for x in 0..<580 {
                    let i=(y*580+x)*4
                    let inside=CGRect(x:294,y:252,width:44,height:36).contains(CGPoint(x:x,y:y)) || CGRect(x:368,y:252,width:44,height:36).contains(CGPoint(x:x,y:y))
                    if !inside {check(data[i..<i+4]==neutral[i..<i+4],"pixels outside eyes unchanged")}
                    else {for c in 0..<3 {maxStep=max(maxStep,abs(Int(data[i+c])-Int(prior[i+c])))}}
                }}
                prior=data
            }
            check(prior==acceptedPupil,"exact accepted 50-percent pupil endpoint")
            print("METRIC eye-return/new-grab widthFrom=\(fromWidth), max30Hz channel step=\(maxStep)/255")
        }
        // Fine reverse-path samples catch masking/quantization discontinuities
        // separately from the intentionally faster 240ms handover.
        var previous=render(1,1),fine=0
        for step in 1...256 {
            let t=Double(step)/256,data=render(1-t,1+0.5*t)
            for y in 252..<288 {for x in 294..<412 {let i=(y*580+x)*4
                for c in 0..<3 {fine=max(fine,abs(Int(data[i+c])-Int(previous[i+c])))}}
            }
            previous=data
        }
        check(fine<=5,"reverse joint path must not toggle an eye patch")
        print("PASS reverse grab66 frames: eye-only bounds/closed/accepted50-percent exact, fine step \(fine)/255")
    }
}
