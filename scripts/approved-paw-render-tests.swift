import AppKit

@main struct ApprovedPawRenderTests {
    static func main() throws {
        _=NSApplication.shared
        let view=try NativeCatView(resources:URL(fileURLWithPath:"src"))
        view.frame=NSRect(x:0,y:0,width:290,height:267)
        for (x,side) in [(0.535,"left"),(0.685,"right")] {
            for (age,phase) in [(0.3744,"extend"),(0.52,"contact"),(0.82,"retract")] {
                var toy=CatToy();toy.start(0);toy.grab(0.1)
                toy.move(to:CGPoint(x:x,y:CatToy.groundY(x)),at:0.3)
                toy.release(1);_=toy.frame(1.08)
                let f=toy.frame(1.08+age)
                view.toyFrame=f
                var p=CatPose()
                p.paw=PawPose(raise:f.paw,toyElbow:f.pawElbow,toyWrist:f.pawWrist,toySide:f.pawSide)
                view.update(p)
                let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:580,pixelsHigh:534,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
                bitmap.size=view.bounds.size;view.cacheDisplay(in:view.bounds,to:bitmap)
                // Match the decoded format of the accepted preview PNGs.
                let actual=NSBitmapImageRep(data:bitmap.representation(using:.png,properties:[:])!)!
                let url=URL(fileURLWithPath:"scripts/fixtures/approved-paw-v2/refined-\(side)-\(phase).png")
                let expected=NSBitmapImageRep(data:try Data(contentsOf:url))!
                precondition(actual.pixelsWide==expected.pixelsWide && actual.pixelsHigh==expected.pixelsHigh && actual.bytesPerRow==expected.bytesPerRow)
                let size=actual.bytesPerRow*actual.pixelsHigh
                guard Data(bytes:actual.bitmapData!,count:size)==Data(bytes:expected.bitmapData!,count:size) else {
                    fputs("FAIL real release render differs from accepted preview: \(side) \(phase)\n",stderr);exit(1)
                }
            }
        }
        print("PASS six real drag/release frames pixel-identical to user-accepted 290pt preview")
    }
}
