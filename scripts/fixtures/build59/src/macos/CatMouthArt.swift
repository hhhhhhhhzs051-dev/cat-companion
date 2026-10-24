import AppKit
import CoreImage

// Optional local component: original cat and bed pixels are never edited.
final class CatMouthArt {
    private let texture:NSImage
    private let bitmapReference:NSGraphicsContext
    init(textureURL:URL)throws {
        guard let image=NSImage(contentsOf:textureURL),image.isValid else{throw NSError(domain:"CatMouthAssets",code:1)}
        texture=image
        // Reference only: fixes the snapshot format to the old TIFF's 8-bit sRGB.
        // Its dimensions are irrelevant; NSImage draws into its own full-size bitmap.
        guard let context=CGContext(data:nil,width:1,height:1,bitsPerComponent:8,bytesPerRow:0,
                                    space:CGColorSpace(name:CGColorSpace.sRGB)!,
                                    bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)
        else{throw NSError(domain:"CatMouthAssets",code:2)}
        bitmapReference=NSGraphicsContext(cgContext:context,flipped:false)
    }
    func overlay(_ pose:MouthPose)->CIImage? {
        let amount=max(0,min(1,pose.extensionAmount))
        let opening=max(0,min(1,pose.opening))
        guard amount>0 || opening>0 else{return nil}
        let curl=max(0,min(1,pose.curl))
        let image=NSImage(size:NSSize(width:1254,height:1254),flipped:true){[self] _ in
            let ctx=NSGraphicsContext.current!.cgContext
            let root=CGPoint(x:798,y:700+3*opening)
            // One shared width for tongue-tip, nose licking and paw grooming (+11%).
            var w=20.0*min(1,amount*3)
            var tipY=root.y+amount*(23-56*curl-3*opening)
            var tipX=root.x+8*curl*amount
            var edgeFold=2*curl
            #if CAT_PAW_EXPERIMENT
            if pose.grooming {
                let sweep=max(0,min(1,pose.sweep)),fold=max(0,min(1,pose.fold))
                w *= 1-0.18*fold
                tipX=root.x+amount*(-14+20*sweep)
                tipY=root.y+amount*(24-8*fold)
                // The wide contact surface sweeps over the fur; its edge turns back on retraction.
                edgeFold=9*fold
            }
            #endif
            // Separate, shallow aperture: the lower edge drops before tongue emergence.
            let mouthWidth=max(w+2,22*opening)
            NSColor(calibratedRed:0.27,green:0.18,blue:0.14,alpha:min(1,max(amount*4,opening*3))*0.85).setFill()
            NSBezierPath(ovalIn:NSRect(x:root.x-mouthWidth,y:699,width:2*mouthWidth,height:3*amount+9*opening)).fill()
            guard amount>0 else{return true}
            let path=NSBezierPath()
            path.move(to:CGPoint(x:root.x-w,y:root.y))
            path.curve(to:CGPoint(x:tipX,y:tipY),controlPoint1:CGPoint(x:root.x-w-2,y:root.y+(tipY-root.y)*0.65),controlPoint2:CGPoint(x:tipX-w,y:tipY-edgeFold))
            path.curve(to:CGPoint(x:root.x+w,y:root.y),controlPoint1:CGPoint(x:tipX+w,y:tipY-edgeFold),controlPoint2:CGPoint(x:root.x+w+9*curl,y:root.y+(tipY-root.y)*0.45))
            path.close()
            ctx.saveGState();path.addClip()
            let rect=path.bounds.insetBy(dx:-1,dy:-1)
            // Sample only interior paint. Runtime clipping excludes all generated halo pixels.
            let source=NSRect(x:texture.size.width*0.28,y:texture.size.height*0.30,width:texture.size.width*0.44,height:texture.size.height*0.45)
            texture.draw(in:rect,from:source,operation:.sourceOver,fraction:1,respectFlipped:true,hints:[.interpolation:NSImageInterpolation.high])
            ctx.restoreGState()
            return true
        }
        // Keep the same AppKit drawing, but pass its immutable bitmap directly to CI.
        // A TIFF round trip here encodes/decodes the whole canvas on every mouth frame.
        // Identity CTM pins pixels to the original 1254 canvas, even on Retina displays.
        var rect=NSRect(x:0,y:0,width:1254,height:1254)
        guard let bitmap=image.cgImage(forProposedRect:&rect,context:bitmapReference,hints:[.ctm:NSAffineTransform()]) else{return nil}
        return CIImage(cgImage:bitmap)
    }
}
