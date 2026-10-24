import AppKit
import ImageIO
import UniformTypeIdentifiers

@main struct NoseRender {
    static func main() throws {
        _ = NSApplication.shared
        let output=URL(fileURLWithPath:"reports/nose-v3")
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        let view=try NativeCatView(resources:URL(fileURLWithPath:"src"))
        func capture(_ mouth:MouthPose,width:Int=600,base:CatPose=CatPose())->CGImage {
            view.frame=NSRect(x:0,y:0,width:width,height:Int(Double(width)*1085/1525+60))
            var pose=base;pose.mouth=mouth;view.update(pose)
            let b=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:Int(view.bounds.height),bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
            view.cacheDisplay(in:view.bounds,to:b)
            return b.cgImage!
        }
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
        let art=try CatMouthArt(textureURL:URL(fileURLWithPath:"src/assets/cat-tongue-v1.png"))
        let context=CIContext()
        for (name,pose) in [("tip",MouthPose(extensionAmount:1)),("nose",MouthPose(extensionAmount:1,curl:1)),("paw",MouthPose(extensionAmount:1,grooming:true))] {
            let layer=art.overlay(pose)!
            let bitmap=NSBitmapImageRep(cgImage:context.createCGImage(layer,from:layer.extent)!)
            var left=1254,right=0
            for y in 0..<1254 {for x in 755...840 {
                if bitmap.colorAt(x:x,y:y)!.alphaComponent>0.5 {left=min(left,x);right=max(right,x)}
            }}
            check(right-left+1>=42,"\(name) tongue/mouth footprint must use the wider surface, not the old narrow variant")
        }
        let rest=capture(MouthPose())
        let preparation=capture(CatMouth.pose(.noseLick,elapsed:0.07))
        check(!changed(rest,preparation).isEmpty,"Mouth must visibly open before any tongue appears")
        let open=capture(MouthPose(opening:1))
        check(changed(preparation,open).count>10,"Cached view must redraw when only opening changes")
        let chinChanges=changed(rest,open).filter{(348...385).contains($0.x) && (281...300).contains($0.y)}
        check(chinChanges.count>20,"Opening must move original chin pixels, not only draw a mouth oval")
        let chin=CatDeformation.sourcePoint(CGPoint(x:798,y:725),pose:CatPose(mouth:MouthPose(opening:1)))
        check(chin.y<723 && chin.y>=719 && chin.x==798,"Chin inverse follows a small downward motion")
        for anchor in [CGPoint(x:798,y:670),CGPoint(x:685,y:551),CGPoint(x:882,y:551),CGPoint(x:798,y:805)] {
            check(CatDeformation.sourcePoint(anchor,pose:CatPose(mouth:MouthPose(opening:1)))==anchor,"Nose, eyes and bed-side neck remain anchored")
        }
        // No fold-over or hard seam through the feathered chin/neck transition.
        for x in stride(from:700,through:900,by:5) {
            var previous=CatDeformation.sourcePoint(CGPoint(x:x,y:690),pose:CatPose(mouth:MouthPose(opening:1)))
            for y in 691...800 {
                let q=CatDeformation.sourcePoint(CGPoint(x:x,y:y),pose:CatPose(mouth:MouthPose(opening:1)))
                check(q.y>previous.y && q.y-previous.y<1.25,"Chin deformation must remain continuous without folding")
                previous=q
            }
        }
        for (i,t) in [0.0,0.07,0.18,0.32,0.5,0.7,0.9,1.08].enumerated() {
            let im=capture(CatMouth.pose(.noseLick,elapsed:t))
            save(im,"phase-\(i)")
            let delta=changed(rest,im)
            check(delta.allSatisfy{(325...410).contains($0.x) && (250...307).contains($0.y)},"Only the mouth/nose/chin region may change")
            if t==1.08 {check(delta.isEmpty,"Exact return to V1 pixels")}
        }
        for width in [300,600] {
            let destination=CGImageDestinationCreateWithURL(output.appendingPathComponent("nose-\(width).gif") as CFURL,UTType.gif.identifier as CFString,72,nil)!
            CGImageDestinationSetProperties(destination,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
            for frame in 0..<72 {
                let pose=CatMouth.pose(.noseLick,elapsed:Double(frame)/30-0.5)
                let im=capture(pose,width:width)
                // Opaque preview background avoids GIF disposal trails; source remains transparent.
                let ctx=CGContext(data:nil,width:im.width,height:im.height,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
                ctx.setFillColor(CGColor(red:0.10,green:0.10,blue:0.10,alpha:1));ctx.fill(CGRect(x:0,y:0,width:im.width,height:im.height))
                ctx.draw(im,in:CGRect(x:0,y:0,width:im.width,height:im.height))
                CGImageDestinationAddImage(destination,ctx.makeImage()!,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:1.0/30]] as CFDictionary)
            }
            check(CGImageDestinationFinalize(destination),"GIF export succeeds")
            let all=CGImageDestinationCreateWithURL(output.appendingPathComponent("all-actions-\(width).gif") as CFURL,UTType.gif.identifier as CFString,288,nil)!
            CGImageDestinationSetProperties(all,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
            for frame in 0..<288 {
                let t=Double(frame)/30
                var pose=CatPose()
                if t<2.4 {pose.mouth=CatMouth.pose(.tongueTip,elapsed:t-0.5)}
                else if t<4.8 {pose.mouth=CatMouth.pose(.noseLick,elapsed:t-2.9)}
                else {let g=CatGrooming.pose(elapsed:t-5.1);pose=g.cat;pose.paw=g.paw}
                let im=capture(pose.mouth,width:width,base:pose)
                if width==600 && [27,99,199].contains(frame) {save(im,"action-\(frame)")}
                let ctx=CGContext(data:nil,width:im.width,height:im.height,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
                ctx.setFillColor(CGColor(red:0.1,green:0.1,blue:0.1,alpha:1));ctx.fill(CGRect(x:0,y:0,width:im.width,height:im.height))
                ctx.draw(im,in:CGRect(x:0,y:0,width:im.width,height:im.height))
                CGImageDestinationAddImage(all,ctx.makeImage()!,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:1.0/30]] as CFDictionary)
            }
            check(CGImageDestinationFinalize(all),"All-action GIF export succeeds")
        }
        print("PASS visible preparation, mouth-only cache refresh, mouth-region isolation, exact V1 restoration; exported 300/600 previews")
    }
}
