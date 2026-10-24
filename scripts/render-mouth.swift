import AppKit
import ImageIO
import UniformTypeIdentifiers

@main struct MouthRender {
    static func main() throws {
        _ = NSApplication.shared
        let output=URL(fileURLWithPath:"reports/mouth-stage")
        let view=try NativeCatView(resources:URL(fileURLWithPath:"src"))
        view.mouthArt=try CatMouthArt(textureURL:output.appendingPathComponent("assets/tongue-candidate-2.png"))
        func capture(_ p:MouthPose,width:Int=600)->CGImage {
            view.frame=NSRect(x:0,y:0,width:Double(width),height:Double(width)*1085/1525+60)
            view.update(CatPose(mouth:p));view.mouthPose=p
            let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:Int(view.bounds.height),bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
            view.cacheDisplay(in:view.bounds,to:bitmap)
            return bitmap.cgImage!
        }
        func save(_ image:CGImage,_ name:String) {
            let dest=CGImageDestinationCreateWithURL(output.appendingPathComponent(name+".png") as CFURL,UTType.png.identifier as CFString,1,nil)!
            CGImageDestinationAddImage(dest,image,nil);precondition(CGImageDestinationFinalize(dest))
        }
        let rest=capture(MouthPose())
        let overlay=view.mouthArt!.overlay(MouthPose(extensionAmount:1))!
        let overlayCG=CIContext().createCGImage(overlay,from:overlay.extent)!
        let overlayBitmap=NSBitmapImageRep(cgImage:overlayCG)
        var minX=1254,maxX=0
        for y in 0..<1254 {for x in 750..<850 {
            if (overlayBitmap.colorAt(x:x,y:y)?.alphaComponent ?? 0)>0.5 {minX=min(minX,x);maxX=max(maxX,x)}
        }}
        precondition(maxX-minX>=34,"Tongue overlay must have a broad, readable silhouette rather than a thin line")
        save(rest,"rest")
        func unchangedOutsideMouth(_ image:CGImage) {
            let a=NSBitmapImageRep(cgImage:rest),b=NSBitmapImageRep(cgImage:image)
            var changed=0
            var changedBounds=CGRect.null
            for y in 0..<image.height {for x in 0..<image.width {
                if (350...390).contains(x) && (245...291).contains(y) {continue}
                let p=a.colorAt(x:x,y:y)!.usingColorSpace(.deviceRGB)!,q=b.colorAt(x:x,y:y)!.usingColorSpace(.deviceRGB)!
                if max(abs(p.redComponent-q.redComponent),abs(p.greenComponent-q.greenComponent),abs(p.blueComponent-q.blueComponent),abs(p.alphaComponent-q.alphaComponent))>1.01/255 {changed+=1;changedBounds=changedBounds.union(CGRect(x:x,y:y,width:1,height:1))}
            }}
            if changed>0 {fputs("Outside ROI differences: \(changed), bounds: \(changedBounds)\n",stderr);save(image,"diagnostic-mouth-tested")}
            precondition(changed==0,"Mouth overlay must not modify face, markings, body or bed outside its local ROI")
        }
        for (name,gesture) in [("tongue-tip",MouthGesture.tongueTip),("nose-lick",.noseLick)] {
            for (suffix,t) in [("enter",0.10),("peak",0.32),("exit",0.60)] {
                save(capture(CatMouth.pose(gesture,elapsed:t)),name+"-"+suffix)
            }
            unchangedOutsideMouth(capture(CatMouth.pose(gesture,elapsed:0.32)))
            save(capture(CatMouth.pose(gesture,elapsed:0.32),width:300),name+"-normal")
            unchangedOutsideMouth(capture(CatMouth.pose(gesture,elapsed:0.32)))
            let after=capture(CatMouth.pose(gesture,elapsed:2))
            precondition(NSBitmapImageRep(cgImage:rest).representation(using:.png,properties:[:])==NSBitmapImageRep(cgImage:after).representation(using:.png,properties:[:]),"Rest image must be restored exactly")
        }
        let frames=180
        let gif=CGImageDestinationCreateWithURL(output.appendingPathComponent("mouth-preview.gif") as CFURL,UTType.gif.identifier as CFString,frames,nil)!
        CGImageDestinationSetProperties(gif,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
        for index in 0..<frames {autoreleasepool {
            let t=Double(index)/30
            let p=t<3 ? CatMouth.pose(.tongueTip,elapsed:t-1):CatMouth.pose(.noseLick,elapsed:t-4)
            CGImageDestinationAddImage(gif,capture(p),[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:1.0/30]] as CFDictionary)
        }}
        precondition(CGImageDestinationFinalize(gif))
        var demo=CatMotion(now:0,seed:9)
        demo.startDemo(0)
        let demoGIF=CGImageDestinationCreateWithURL(output.appendingPathComponent("visibility-demo.gif") as CFURL,UTType.gif.identifier as CFString,360,nil)!
        CGImageDestinationSetProperties(demoGIF,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
        for i in 0..<360 {autoreleasepool {
            let t=Double(i)/30
            view.text=demo.demoLabel(t) ?? ""
            let pose=demo.frame(t,reduced:false,paused:false)
            CGImageDestinationAddImage(demoGIF,capture(pose.mouth,width:300),[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:1.0/30]] as CFDictionary)
        }}
        precondition(CGImageDestinationFinalize(demoGIF))
        view.text=""
        view.pawArt=try CatPawArt(referenceURL:output.appendingPathComponent("assets/paw-contact-candidate.png"))
        for (name,t) in [("paw-enter",0.7),("paw-contact",1.25),("paw-return",2.95)] {
            view.pawPose=CatPaw.pose(elapsed:t)
            save(capture(MouthPose(extensionAmount:view.pawPose.lick)),name)
        }
        let pawGIF=CGImageDestinationCreateWithURL(output.appendingPathComponent("paw-experiment.gif") as CFURL,UTType.gif.identifier as CFString,150,nil)!
        CGImageDestinationSetProperties(pawGIF,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
        for i in 0..<150 {autoreleasepool {
            view.pawPose=CatPaw.pose(elapsed:Double(i)/30-0.5)
            CGImageDestinationAddImage(pawGIF,capture(MouthPose(extensionAmount:view.pawPose.lick)),[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:1.0/30]] as CFDictionary)
        }}
        precondition(CGImageDestinationFinalize(pawGIF))
        print("PASS exact V1.1.1 rest restoration; exported 6s native mouth sample and normal-size/peak/transition images. Visual approval pending.")
    }
}
