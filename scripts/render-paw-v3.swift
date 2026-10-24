import AppKit
import ImageIO
import UniformTypeIdentifiers

@main struct PawV3Render {
    static func main() throws {
        _ = NSApplication.shared
        let output=URL(fileURLWithPath:"reports/paw-v3.1")
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        let view=try NativeCatView(resources:URL(fileURLWithPath:"src"))
        view.pawArt=try CatPawArt(referenceURL:URL(fileURLWithPath:"reports/mouth-stage/assets/paw-contact-candidate.png"))
        func capturePose(_ p:GroomingPose,width:Int=600)->CGImage {
            view.frame=NSRect(x:0,y:0,width:width,height:Int(Double(width)*1085/1525+60))
            var pose=p.cat;pose.paw=p.paw;view.update(pose)
            let b=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:Int(view.bounds.height),bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
            view.cacheDisplay(in:view.bounds,to:b)
            return b.cgImage!
        }
        func capture(_ t:Double,width:Int=600)->CGImage {capturePose(CatGrooming.pose(elapsed:t),width:width)}
        func save(_ im:CGImage,_ name:String) {
            let d=CGImageDestinationCreateWithURL(output.appendingPathComponent(name+".png") as CFURL,UTType.png.identifier as CFString,1,nil)!
            CGImageDestinationAddImage(d,im,nil);precondition(CGImageDestinationFinalize(d))
        }
        func changed(_ a:CGImage,_ b:CGImage)->[CGPoint] {
            let lhs=NSBitmapImageRep(cgImage:a),rhs=NSBitmapImageRep(cgImage:b)
            var result=[CGPoint]()
            for y in 0..<a.height {for x in 0..<a.width {
                let p=lhs.colorAt(x:x,y:y)!.usingColorSpace(.deviceRGB)!,q=rhs.colorAt(x:x,y:y)!.usingColorSpace(.deviceRGB)!
                if max(abs(p.redComponent-q.redComponent),abs(p.greenComponent-q.greenComponent),abs(p.blueComponent-q.blueComponent),abs(p.alphaComponent-q.alphaComponent))>1.01/255 {result.append(CGPoint(x:x,y:y))}
            }}
            return result
        }
        func check(_ ok:Bool,_ message:String) {if !ok {fputs("FAIL: \(message)\n",stderr);exit(1)}}
        // Exercise the actual view cache and raster path: scalar extension alone must not pass.
        var stroke=CatGrooming.pose(elapsed:1.55)
        stroke.cat.mouth.extensionAmount=1;stroke.cat.mouth.sweep=0
        let from=capturePose(stroke)
        stroke.cat.mouth.sweep=1
        let to=capturePose(stroke)
        check(changed(from,to).count>15,"Rendered tongue must sweep at equal extension, including cached drawing")
        stroke.cat.mouth.fold=0.8
        check(changed(to,capturePose(stroke)).count>10,"Rendered tongue must fold independently of shortening")
        stroke.paw.offsetX=0
        let centered=capturePose(stroke)
        stroke.paw.offsetX = -12
        check(changed(centered,capturePose(stroke)).count>40,"Rendered paw must follow its off-center approach")

        let baseline=capture(0);save(baseline,"rest")
        if ProcessInfo.processInfo.environment["CAT_GROOM_DIAGNOSTIC"]=="1" {
            let diagnosticFront=NativeCatView.path("M-98 625 C-98 872 1348 872 1348 625 L1348 1274 L-98 1274 Z")
            for (name,p) in [("head",GroomingPose(cat:CatPose(head:3.4))),("eyes",GroomingPose(cat:CatPose(eyes:0.68))),("paw",GroomingPose(paw:CatGrooming.pose(elapsed:0.95).paw))] {
                let im=capturePose(p);save(im,"diagnostic-"+name)
                let points=changed(baseline,im)
                let outside=points.filter{$0.x<210}
                let a=NSBitmapImageRep(cgImage:baseline),b=NSBitmapImageRep(cgImage:im)
                var maxDiff=0.0
                for p in outside {
                    let x=Int(p.x),y=Int(p.y),l=a.colorAt(x:x,y:y)!.usingColorSpace(.deviceRGB)!,r=b.colorAt(x:x,y:y)!.usingColorSpace(.deviceRGB)!
                    maxDiff=max(maxDiff,abs(l.redComponent-r.redComponent),abs(l.greenComponent-r.greenComponent),abs(l.blueComponent-r.blueComponent),abs(l.alphaComponent-r.alphaComponent))
                }
                print("DIAG \(name): outside \(outside.count), bounds \(outside.reduce(CGRect.null){$0.union(CGRect(origin:$1,size:CGSize(width:1,height:1)))}), max channel delta \(maxDiff*255)")
                let bed=points.filter{diagnosticFront.contains(CGPoint(x:($0.x+0.5)*1525/600-135,y:($0.y+0.5-60)*1525/600+165))}
                print("DIAG \(name) bed: \(bed.count) \(bed.prefix(6))")
            }
            return
        }
        let front=NativeCatView.path("M-98 625 C-98 872 1348 872 1348 625 L1348 1274 L-98 1274 Z")
        let times=[0.2,0.6,0.95,1.25,1.52,1.66,1.80,2.26,2.52,3.0,3.3,3.75]
        for (i,t) in times.enumerated() {
            let im=capture(t);save(im,"phase-\(i)")
            let pixels=changed(baseline,im)
            let outside=pixels.filter{!(210...490).contains($0.x) || !(50...322).contains($0.y)}
            check(outside.isEmpty,"Phase \(i) changes \(outside.count) pixels outside authorized head/paw area: \(outside.prefix(3))")
            let bed=pixels.filter{front.contains(CGPoint(x:($0.x+0.5)*1525/600-135,y:($0.y+0.5-60)*1525/600+165))}
            check(bed.isEmpty,"Phase \(i) changes \(bed.count) foreground bed pixels")
            if i==4 {check(pixels.count>100,"Grooming must actually be rendered")}
            let pose=CatGrooming.pose(elapsed:t).cat
            let originalEyes=capturePose(GroomingPose(cat:CatPose(head:pose.head,groomingProfile:true)))
            let eyeChanges=changed(originalEyes,im).filter{(285...430).contains($0.x) && (190...240).contains($0.y)}
            check(eyeChanges.isEmpty,"Phase \(i) must retain V1 eye pixels at the same head pose")
            let left=CatDeformation.sourcePoint(CGPoint(x:685,y:551),pose:pose)
            let right=CatDeformation.sourcePoint(CGPoint(x:882,y:551),pose:pose)
            check(abs(hypot(left.x-right.x,left.y-right.y)-197)<0.001,"Eye spacing remains rigid during head motion")
        }
        check(changed(baseline,capture(4)).isEmpty,"Exact return to V1 rest")
        let normalRest=capture(0,width:300)
        for (i,t) in times.enumerated() {
            let im=capture(t,width:300)
            let head=CatGrooming.pose(elapsed:t).cat.head
            let originalEyes=capturePose(GroomingPose(cat:CatPose(head:head,groomingProfile:true)),width:300)
            let eyeChanges=changed(originalEyes,im).filter{(143...215).contains($0.x) && (125...150).contains($0.y)}
            check(eyeChanges.isEmpty,"Normal-size phase \(i) must retain V1 eye pixels at the same head pose")
            let pixels=changed(normalRest,im)
            check(pixels.allSatisfy{(105...245).contains($0.x) && (55...191).contains($0.y)},"Normal-size phase \(i) stays inside head/paw area")
            let bed=pixels.filter{front.contains(CGPoint(x:($0.x+0.5)*1525/300-135,y:($0.y+0.5-60)*1525/300+165))}
            check(bed.isEmpty,"Normal-size phase \(i) changes \(bed.count) foreground bed pixels")
        }
        save(capture(1.66,width:300),"contact-normal")
        for width in [600,300] {
            let dest=CGImageDestinationCreateWithURL(output.appendingPathComponent("paw-v3.1-\(width).gif") as CFURL,UTType.gif.identifier as CFString,144,nil)!
            CGImageDestinationSetProperties(dest,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
            for i in 0..<144 {autoreleasepool {
                CGImageDestinationAddImage(dest,capture(Double(i)/24-0.7,width:width),[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:1.0/24]] as CFDictionary)
            }}
            check(CGImageDestinationFinalize(dest),"GIF export succeeds")
        }
        print("PASS actual tongue sweep/fold, cached paw offset, 12 phases at both 300/600px for head/paw ROI and foreground-bed invariance, rigid eye spacing, exact rest; previews exported. Naturalness still requires visual review.")
    }
}
