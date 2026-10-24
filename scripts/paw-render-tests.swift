import AppKit
import CoreImage

@main struct PawRenderTests {
    static func main() throws {
        _=NSApplication.shared
        let url=URL(fileURLWithPath:"src/assets/cat-paw-contact-v1.png")
        let old=try LegacyBuild47PawArt(referenceURL:url),new=try CatPawArt(referenceURL:url)
        let context=CIContext(options:[.cacheIntermediates:false])
        func pixels(_ image:CIImage,_ scale:Double)->[UInt8] {
            let scaled=image.transformed(by:CGAffineTransform(scaleX:scale,y:scale)),rect=scaled.extent.integral
            let row=Int(rect.width)*4
            var data=[UInt8](repeating:0,count:row*Int(rect.height))
            context.render(scaled,toBitmap:&data,rowBytes:row,bounds:rect,format:.RGBA8,colorSpace:CGColorSpace(name:CGColorSpace.sRGB)!)
            return data
        }
        for time in stride(from:0.0,through:3.6,by:0.12) {
            autoreleasepool {
                let pose=CatPaw.pose(elapsed:time),a=old.overlay(pose),b=new.overlay(pose)
                precondition((a == nil)==(b == nil))
                if let a,let b {
                    for scale in [290.0/1525,580.0/1525] {precondition(pixels(a,scale)==pixels(b,scale),"Existing grooming paw pixels must not change")}
                }
            }
        }
        // Frozen renderer, independent literal reflection: catch wrong side,
        // displaced attachments, or color edits even when solver tests pass.
        for x in [0.55,0.57,0.60,0.605] {
            var toy=CatToy();toy.start(0);toy.grab(1)
            toy.move(to:CGPoint(x:0.59,y:0.37),at:1)
            toy.move(to:CGPoint(x:x,y:0.37),at:1);toy.release(1.1)
            for step in 0...60 {
                let f=toy.frame(1.1+Double(step)/30)
                if f.paw==0 {continue}
                autoreleasepool {
                    var p=PawPose(raise:f.paw,toyElbow:f.pawElbow,toyWrist:f.pawWrist)
                    let baseline=old.overlay(p)!
                    p.toySide = -1
                    let rightPaw=new.overlay(p)!
                    p.toySide=1
                    let leftPaw=new.overlay(p)!
                    let expectedLeft=baseline.transformed(by:CGAffineTransform(a:-1,b:0,c:0,d:1,tx:1590.5,ty:0)).cropped(to:baseline.extent)
                    for scale in [290.0/1525,580.0/1525] {
                        precondition(pixels(rightPaw,scale)==pixels(baseline,scale),"Screen-left retains every pixel of the original cat-right action")
                        precondition(pixels(leftPaw,scale)==pixels(expectedLeft,scale),"Only screen-right gets the mirrored cat-left action")
                    }
                }
            }
        }
        print("PASS unchanged grooming RGBA and original/mirrored single-paw action pixels")
    }
}
