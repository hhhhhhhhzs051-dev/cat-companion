import AppKit
import ImageIO
import UniformTypeIdentifiers

@main struct MicroRender {
    static func main() throws {
        _ = NSApplication.shared
        let view=try NativeCatView(resources:URL(fileURLWithPath:"src"))
        view.frame=NSRect(x:0,y:0,width:600,height:488)
        let out=URL(fileURLWithPath:"reports/v111-polish")
        try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
        func capture(_ pose:CatPose)->CGImage {
            view.update(pose)
            let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:600,pixelsHigh:488,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
            view.cacheDisplay(in:view.bounds,to:rep)
            return rep.cgImage!
        }
        let rest=capture(CatPose())
        view.useV1Rendering=true
        let v1=capture(CatPose())
        let original=CGImageDestinationCreateWithURL(out.appendingPathComponent("v1-reference.png") as CFURL,UTType.png.identifier as CFString,1,nil)!
        CGImageDestinationAddImage(original,v1,nil);precondition(CGImageDestinationFinalize(original))
        view.useV1Rendering=false
        let epsilon=capture(CatPose(breath:0.00000001))
        let a=NSBitmapImageRep(cgImage:rest), b=NSBitmapImageRep(cgImage:epsilon)
        var sum=0.0,maxDifference=0.0
        for y in 0..<488 {for x in 0..<600 {
            let ca=a.colorAt(x:x,y:y)!.usingColorSpace(.deviceRGB)!,cb=b.colorAt(x:x,y:y)!.usingColorSpace(.deviceRGB)!
            for d in [abs(ca.redComponent-cb.redComponent),abs(ca.greenComponent-cb.greenComponent),abs(ca.blueComponent-cb.blueComponent),abs(ca.alphaComponent-cb.alphaComponent)] {sum+=d;maxDifference=max(maxDifference,d)}
        }}
        print("Zero-motion transition mean difference: \(sum/(600*488*4)), maximum: \(maxDifference)")
        precondition(sum/(600*488*4)<0.005,"Visible static/animated pipeline mismatch")
        for (name,pose) in [("rest",CatPose()),("half",CatPose(eyes:0.5)),("quarter",CatPose(eyes:0.25)),("almost",CatPose(eyes:0.8)),("breath",CatPose(breath:1)),("ear-left",CatPose(leftEar:1)),("ear-right",CatPose(rightEar:1)),("head-up",CatPose(head:-1)),("head-down",CatPose(head:1)),("pet",CatPose(eyes:1,breath:0.4,lean:1))] {
            let dst=CGImageDestinationCreateWithURL(out.appendingPathComponent(name+".png") as CFURL,UTType.png.identifier as CFString,1,nil)!
            CGImageDestinationAddImage(dst,capture(pose),nil);precondition(CGImageDestinationFinalize(dst))
        }
        for cache in [false,true] {
            view.cacheEnabled=cache
            let start=ProcessInfo.processInfo.systemUptime
            var motion=CatMotion(now:0,seed:55)
            for i in 0..<600 {autoreleasepool {_ = capture(motion.frame(Double(i)/30,reduced:false,paused:false))}}
            print("600 native frames, cache=\(cache): \(ProcessInfo.processInfo.systemUptime-start)s")
        }
        view.cacheEnabled=true
        let frames=450 // Demonstration timing, deliberately denser than real idle behavior.
        let dst=CGImageDestinationCreateWithURL(out.appendingPathComponent("micro-preview.gif") as CFURL,UTType.gif.identifier as CFString,frames,nil)!
        CGImageDestinationSetProperties(dst,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
        var feedback=CatMotion(now:0,seed:42);feedback.pet(9.2)
        let started=ProcessInfo.processInfo.systemUptime
        for index in 0..<frames {
            autoreleasepool {
                let t=Double(index)/30
                func pulse(_ start:Double,_ duration:Double)->Double {let p=(t-start)/duration;return p>=0 && p<1 ? pow(sin(.pi*p),2) : 0}
                let touch=feedback.frame(t,reduced:false,paused:false)
                let slow=0.55*CatMotion.envelope(t-5.3,rise:0.32,hold:0.48,fall:0.58)+0.45*CatMotion.envelope(t-5.72,rise:0.24,hold:0.14,fall:0.42)
                let pose=CatPose(eyes:max(touch.eyes,slow),breath:(1-cos(t/3.75 * .pi*2))/2,lean:touch.lean,leftEar:pulse(1,1.24),rightEar:pulse(7.2,1.24),head:-pulse(3,3.25)+pulse(11.5,3.25))
                CGImageDestinationAddImage(dst,capture(pose),[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:1.0/30]] as CFDictionary)
            }
        }
        precondition(CGImageDestinationFinalize(dst));print("Rendered 10 poses, V1 reference and 15s native preview (demo timing, not idle schedule); export time \(ProcessInfo.processInfo.systemUptime-started)s")
    }
}
