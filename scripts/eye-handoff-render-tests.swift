import AppKit
@main struct EyeHandoffPixels {
    static func main() throws {
        _=NSApplication.shared
        func check(_ ok:Bool,_ s:String){if !ok {print("FAIL handoff pixels: \(s)");exit(1)}}
        let out=URL(fileURLWithPath:CommandLine.arguments[1])
        let view=try NativeCatView(resources:URL(fileURLWithPath:"src"))
        view.frame=NSRect(x:0,y:0,width:290,height:267)
        func render(_ gaze:Double,_ width:Double,_ eyes:Double=0)->(Data,NSBitmapImageRep) {
            view.update(CatPose(eyes:eyes))
            view.eyeAim=CatEyeAim(x:gaze,fixedApertureX:1,gain:1.5)
            view.eyeVariation=EyeVariation(pupilWidth:width,fixedAperture:true,pupilLimit:1.5)
            let b=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:580,pixelsHigh:534,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
            b.size=view.bounds.size;view.cacheDisplay(in:view.bounds,to:b)
            return (Data(bytes:b.bitmapData!,count:b.bytesPerRow*b.pixelsHigh),b)
        }
        let original=render(0,1).0
        for (label,g,w) in [("neutral",0.0,1.0),("pupil",0,1.5),("gaze",1,1),("gaze-half",0.5,1)] {
            let b=render(g,w).1;try b.representation(using:.png,properties:[:])!.write(to:out.appendingPathComponent(label+".png"))
        }
        #if CAT_EYE_HANDOFF_PREVIEW || CAT_EYE_HANDOFF
        let combined=render(1,1.5).0
        check(combined != original && combined != render(1,1).0 && combined != render(0,1.5).0,"both effects remain visible; neither overwritten")
        let closed=render(0,1,1).0
        check(render(1,1.5,1).0==closed,"closed endpoint exact")
        var maxDelta=0,previous=render(0,1.5).0,maxGazeDelta=0,previousGaze=original
        var gaze=CatAccessoryGaze();_=gaze.tap(at:0,allowed:true)
        for frame in 0...45 {
            let t=Double(frame)/30,phase=min(1,t/0.8),w=1+0.5*(1-phase*phase*(3-2*phase))
            let aim=gaze.sample(at:t,allowed:true).eye
            let (data,b)=render(aim,w)
            let gazeOnly=render(aim,1).0
            for y in 0..<534 {for x in 0..<580 {
                let inside=CGRect(x:294,y:252,width:44,height:36).contains(CGPoint(x:x,y:y)) || CGRect(x:368,y:252,width:44,height:36).contains(CGPoint(x:x,y:y))
                let i=y*b.bytesPerRow+x*4
                if !inside {check(data[i..<i+4]==original[i..<i+4],"outside eyes changed")}
                else {for c in 0..<3 {
                    maxDelta=max(maxDelta,abs(Int(data[i+c])-Int(previous[i+c])))
                    maxGazeDelta=max(maxGazeDelta,abs(Int(gazeOnly[i+c])-Int(previousGaze[i+c])))
                }}
            }}
            if [0,3,6,12,24,45].contains(frame) {try b.representation(using:.png,properties:[:])!.write(to:out.appendingPathComponent("handoff-\(frame).png"))}
            previous=data
            previousGaze=gazeOnly
        }
        check(previous==original,"exact neutral recovery")
        var fine=0;previous=render(0,1.5).0
        for step in 1...256 {
            let t=Double(step)/256,w=1.5-0.5*t
            let (data,b)=render(t,w)
            for y in 252..<288 {for x in 294..<412 {let i=y*b.bytesPerRow+x*4;for c in 0..<3 {fine=max(fine,abs(Int(data[i+c])-Int(previous[i+c])))}}}
            previous=data
        }
        print("METRIC joint fine=\(fine), combined30=\(maxDelta), gaze30=\(maxGazeDelta)")
        check(fine<=5,"joint fine parameter movement must not toggle an eye patch")
        check(maxDelta<=maxGazeDelta,"combined transition must not exceed accepted gaze frame bound")
        print("PASS combined46 frames: both effects visible, outside-eye/closed/neutral exact; max30Hz channel step \(maxDelta)/255, original gaze \(maxGazeDelta)/255, fine step \(fine)/255")
        #endif
        print("PASS single-effect reference frames exported")
    }
}
