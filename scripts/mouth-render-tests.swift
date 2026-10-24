import AppKit
import CoreImage

// Compare against the frozen, shipped build 33 renderer; not a second app bundle.
@main struct MouthRenderTests {
    static func main() throws {
        let url=URL(fileURLWithPath:"src/assets/cat-tongue-v1.png")
        let old=try LegacyMouthArt(textureURL:url),new=try CatMouthArt(textureURL:url)
        let context=CIContext(options:[.cacheIntermediates:false])
        let color=CGColorSpace(name:CGColorSpace.sRGB)!
        var poses=[MouthPose(),MouthPose(extensionAmount:0,curl:0,opening:0.5)]
        for gesture in [MouthGesture.tongueTip,.noseLick] {
            for t in stride(from:0.02,through:1.18,by:0.08) {
                poses.append(CatMouth.pose(gesture,elapsed:t))
            }
        }
        #if CAT_PAW_EXPERIMENT
        for amount in [0.08,0.4,1.0] {
            for sweep in [0.0,0.5,1.0] {
                poses.append(MouthPose(extensionAmount:amount,curl:0,opening:0.6,grooming:true,sweep:sweep,fold:1-sweep))
            }
        }
        #endif
        func pixels(_ image:CIImage,scale:Double=1)->[UInt8] {
            let scaled=image.transformed(by:CGAffineTransform(scaleX:scale,y:scale))
            let bounds=scaled.extent.integral
            let row=Int(bounds.width)*4
            var result=[UInt8](repeating:0,count:row*Int(bounds.height))
            context.render(scaled,toBitmap:&result,rowBytes:row,bounds:bounds,format:.RGBA8,colorSpace:color)
            return result
        }
        let mode=CommandLine.arguments.dropFirst().first ?? "check"
        if mode != "check" {
            precondition(mode == "old" || mode == "new")
            let count=180
            var checksum=0
            let start=ProcessInfo.processInfo.systemUptime,cpu=clock()
            for i in 0..<count {
                autoreleasepool {
                    let pose=poses[2+i%(poses.count-2)]
                    if let image=(mode == "old" ? old.overlay(pose):new.overlay(pose)) {
                        let bytes=pixels(image,scale:580.0/1525.0)
                        checksum += Int(bytes.reduce(0){($0+UInt64($1))%1_000_000_007})
                    }
                }
            }
            print("BENCH \(mode) frames=\(count) wall_s=\(ProcessInfo.processInfo.systemUptime-start) cpu_s=\(Double(clock()-cpu)/Double(CLOCKS_PER_SEC)) checksum=\(checksum)")
            return
        }
        for (i,pose) in poses.enumerated() {
            autoreleasepool {
                let a=old.overlay(pose),b=new.overlay(pose)
                precondition((a == nil) == (b == nil),"nil contract pose \(i)")
                guard let a=a,let b=b else{return}
                precondition(a.extent == b.extent,"extent pose \(i): \(a.extent) vs \(b.extent)")
                for scale in [1.0,290.0/1525.0,580.0/1525.0] {
                    let lhs=pixels(a,scale:scale),rhs=pixels(b,scale:scale)
                    precondition(lhs.count == rhs.count)
                    precondition(lhs == rhs,"pixels pose \(i) scale \(scale) must match build 33 exactly")
                }
            }
        }
        // A CIImage can be rendered lazily: later overlays must not change an earlier one.
        let retained:CIImage=autoreleasepool {new.overlay(poses[8])!}
        let before=pixels(retained)
        for pose in poses {autoreleasepool {_ = new.overlay(pose)}}
        precondition(before == pixels(retained),"image lifetime changed after subsequent frames")
        // NativeCat calls overlay during view drawing with a flipped/scaled context.
        for backing in [1.0,2.0] {
            autoreleasepool {
                let cg=CGContext(data:nil,width:600,height:600,bitsPerComponent:8,bytesPerRow:0,
                                 space:color,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
                cg.translateBy(x:17,y:267*backing)
                cg.scaleBy(x:backing,y:-backing)
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current=NSGraphicsContext(cgContext:cg,flipped:true)
                defer{NSGraphicsContext.restoreGraphicsState()}
                precondition(pixels(new.overlay(poses[8])!) == before,"ambient view context changed pixels")
            }
        }
        print("PASS mouth render: \(poses.count) poses; RGBA exact full/normal 1x/2x; nil/extent/pool-lifetime")
    }
}
