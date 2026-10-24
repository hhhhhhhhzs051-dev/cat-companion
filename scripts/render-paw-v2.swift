import AppKit
import ImageIO
import UniformTypeIdentifiers

@main struct PawV2Render {
    static func main() throws {
        _ = NSApplication.shared
        let output=URL(fileURLWithPath:"reports/paw-v2")
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        let view=try NativeCatView(resources:URL(fileURLWithPath:"src"))
        view.pawArt=try CatPawArt(referenceURL:URL(fileURLWithPath:"reports/mouth-stage/assets/paw-contact-candidate.png"))
        func capture(_ t:Double,width:Int=600)->CGImage {
            let paw=CatPaw.pose(elapsed:t)
            view.frame=NSRect(x:0,y:0,width:width,height:Int(Double(width)*1085/1525+60))
            view.update(CatPose(mouth:MouthPose(extensionAmount:paw.lick),paw:paw))
            let b=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:Int(view.bounds.height),bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
            view.cacheDisplay(in:view.bounds,to:b)
            return b.cgImage!
        }
        func save(_ im:CGImage,_ name:String) {
            let d=CGImageDestinationCreateWithURL(output.appendingPathComponent(name+".png") as CFURL,UTType.png.identifier as CFString,1,nil)!
            CGImageDestinationAddImage(d,im,nil);precondition(CGImageDestinationFinalize(d))
        }
        let baseline=capture(0)
        save(baseline,"rest")
        let times=[0.15,0.40,0.65,0.85,1.22,2.80,3.15,3.49]
        for (index,t) in times.enumerated() {
            let im=capture(t);save(im,"phase-\(index)")
            let a=NSBitmapImageRep(cgImage:baseline),b=NSBitmapImageRep(cgImage:im)
            var outside=0,inside=0,bounds=CGRect.null
            for y in 0..<im.height {for x in 0..<im.width {
                let p=a.colorAt(x:x,y:y)!.usingColorSpace(.deviceRGB)!,q=b.colorAt(x:x,y:y)!.usingColorSpace(.deviceRGB)!
                let diff=max(abs(p.redComponent-q.redComponent),abs(p.greenComponent-q.greenComponent),abs(p.blueComponent-q.blueComponent),abs(p.alphaComponent-q.alphaComponent))
                if diff>1.01/255 {
                    if (285...430).contains(x) && (255...318).contains(y) {inside+=1}else{outside+=1;bounds=bounds.union(CGRect(x:x,y:y,width:1,height:1))}
                }
            }}
            guard outside==0 else {fputs("FAIL paw phase \(index): \(outside) changed pixels outside paw/mouth ROI \(bounds)\n",stderr);exit(1)}
            if index==0 {precondition(inside==0,"Early lift must stay behind the bed, without a triangular cutout edge")}
            if index==4 {precondition(inside>100,"Contact paw must actually be rendered")}
        }
        let end=capture(4)
        precondition(NSBitmapImageRep(cgImage:baseline).representation(using:.png,properties:[:])==NSBitmapImageRep(cgImage:end).representation(using:.png,properties:[:]),"Paw returns exactly to rest")
        save(capture(1.22,width:300),"contact-normal")
        for width in [600,300] {
            let dest=CGImageDestinationCreateWithURL(output.appendingPathComponent("paw-v2-\(width).gif") as CFURL,UTType.gif.identifier as CFString,120,nil)!
            CGImageDestinationSetProperties(dest,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
            for i in 0..<120 {autoreleasepool {
                CGImageDestinationAddImage(dest,capture(Double(i)/24-0.6,width:width),[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:1.0/24]] as CFDictionary)
            }}
            precondition(CGImageDestinationFinalize(dest))
        }
        print("PASS 8 paw phases: unchanged face/body/bed outside local ROI; nonempty contact; exact return; 300/600px previews exported. Visual acceptance pending.")
    }
}
