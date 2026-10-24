import AppKit
import CoreImage
@main struct PupilPlayPixels {
    static func main() throws {
        func check(_ v:Bool,_ s:String){if !v {print("FAIL pupil50 pixels: \(s)");exit(1)}}
        _=NSApplication.shared
        let output=URL(fileURLWithPath:CommandLine.arguments[1])
        let view=try NativeCatView(resources:URL(fileURLWithPath:"src"))
        view.frame=NSRect(x:0,y:0,width:290,height:267);view.update(CatPose())
        func bitmap()->NSBitmapImageRep {
            let b=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:580,pixelsHigh:534,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
            b.size=view.bounds.size;view.cacheDisplay(in:view.bounds,to:b);return b
        }
        func bytes(_ b:NSBitmapImageRep)->Data {Data(bytes:b.bitmapData!,count:b.bytesPerRow*b.pixelsHigh)}
        let original=bytes(bitmap());var cue=CatToyPupil();_=cue.beginSession(at:0,allowed:true)
        var previous=original,previous30=original,maxStep=0,maxStep30=0,fineStep=0
        for frame in 0...164 {
            let width=cue.sample(at:Double(frame)/60,allowed:true)
            view.eyeVariation=EyeVariation(pupilWidth:width,fixedAperture:true,pupilLimit:1.5)
            let b=bitmap(),current=bytes(b)
            if frame==60 {check(view.eyeVariation.pupilWidth==1.5 && current != original,"native renderer really reaches50")}
            for y in 0..<534 {for x in 0..<580 {
                let inside=CGRect(x:294,y:252,width:44,height:36).contains(CGPoint(x:x,y:y)) || CGRect(x:368,y:252,width:44,height:36).contains(CGPoint(x:x,y:y))
                let i=y*b.bytesPerRow+x*4
                if inside {for c in 0..<3 {
                    maxStep=max(maxStep,abs(Int(current[i+c])-Int(previous[i+c])))
                    if frame%2==0 {maxStep30=max(maxStep30,abs(Int(current[i+c])-Int(previous30[i+c])))}
                }}
                else {check(current[i..<i+4]==original[i..<i+4],"outside eyes changed at frame\(frame)")}
            }}
            check(view.pose==CatPose(),"no head/body/eyelid changes")
            if width==1 {check(current==original,"exact neutral recovery")}
            if [0,42,114,138,164].contains(frame) {try b.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent("pupil50-\(frame)-290pt.png"))}
            previous=current
            if frame%2==0 {previous30=current}
        }
        previous=original
        for step in 0...256 {
            view.eyeVariation=EyeVariation(pupilWidth:1+0.5*Double(step)/256,fixedAperture:true,pupilLimit:1.5)
            let b=bitmap(),current=bytes(b)
            for y in 252..<288 {for x in 294..<412 {let i=y*b.bytesPerRow+x*4;for c in 0..<3 {fineStep=max(fineStep,abs(Int(current[i+c])-Int(previous[i+c])))}}}
            previous=current
        }
        check(fineStep<=4,"fixed-aperture continuity, no toggling seam")
        check(maxStep<=20,"bounded60Hz sample motion")
        check(maxStep30<=20,"accepted30Hz clock continuity")
        view.eyeVariation = .neutral;view.update(CatPose(eyes:1));let closed=bytes(bitmap())
        view.eyeVariation=EyeVariation(pupilWidth:1.5,fixedAperture:true,pupilLimit:1.5)
        check(bytes(bitmap())==closed,"fully closed eyes exactly unchanged")
        #if CAT_PUPIL_RECOVERY_PREVIEW || CAT_PUPIL_RECOVERY
        // Compare each interrupted eye frame with the unchanged rendering of
        // the same pose. The repair must never move skin, head, body or bed.
        for blink in [false,true] {
            var interrupted=CatToyPupil();_=interrupted.beginSession(at:0,allowed:true)
            _=interrupted.sample(at:0.8,allowed:true)
            for frame in 0...26 {
                let time=Double(frame)/30
                let eyes:Double
                if !blink {eyes=0}
                else if time<0.055 {let t=time/0.055;eyes=t*t*(3-2*t)}
                else if time<0.08 {eyes=1}
                else if time<0.19 {let t=(time-0.08)/0.11;eyes=1-t*t*(3-2*t)}
                else {eyes=0}
                view.update(CatPose(eyes:eyes));view.eyeVariation = .neutral
                let baseline=bytes(bitmap())
                let width=interrupted.sample(at:0.82+time,allowed:false)
                view.eyeVariation=EyeVariation(pupilWidth:width,fixedAperture:true,pupilLimit:1.5)
                let b=bitmap(),current=bytes(b)
                for y in 0..<534 {for x in 0..<580 {
                    let inside=CGRect(x:294,y:252,width:44,height:36).contains(CGPoint(x:x,y:y)) || CGRect(x:368,y:252,width:44,height:36).contains(CGPoint(x:x,y:y))
                    let i=y*b.bytesPerRow+x*4
                    if !inside {check(current[i..<i+4]==baseline[i..<i+4],"interrupted recovery changed pixels outside eyes")}
                }}
                if width==1 || eyes>=0.93 {check(current==baseline,"neutral or closed recovery pixels unchanged")}
                if [0,3,6,12,24].contains(frame) {try b.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent("recovery-\(blink ? "blink":"paw")-\(frame)-290pt.png"))}
            }
        }
        print("PASS54 interrupted290 frames with blink/paw recovery, outside eyes and closed/neutral exact")
        #endif
        print("PASS165 normal290 frames, outside eyes exact, fully closed/neutral exact; maximum60Hz delta \(maxStep)/255, 30Hz \(maxStep30)/255, fine1/256 \(fineStep)/255")
    }
}
