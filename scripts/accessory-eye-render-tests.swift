import AppKit

@main struct AccessoryEyeRenderTests {
    static func check(_ value:Bool,_ message:String) {
        if !value {fputs("FAIL accessory eye pixels: \(message)\n",stderr);exit(1)}
    }
    static func bitmap(_ view:NSView)->NSBitmapImageRep {
        let b=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:580,pixelsHigh:534,bitsPerSample:8,
            samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        b.size=view.bounds.size;view.cacheDisplay(in:view.bounds,to:b);return b
    }
    static func data(_ b:NSBitmapImageRep)->Data {Data(bytes:b.bitmapData!,count:b.bytesPerRow*b.pixelsHigh)}
    static func main() throws {
        _=NSApplication.shared
        let output=URL(fileURLWithPath:CommandLine.arguments[1])
        let before=try NativeCatView(resources:URL(fileURLWithPath:"src"))
        let after=try NativeCatView(resources:URL(fileURLWithPath:"src"))
        before.frame=NSRect(x:0,y:0,width:290,height:267);after.frame=before.frame
        var head=CatAccessoryLook(),eyes=EyeGazePlayback()
        head.tap(at:0,allowed:true);_=eyes.start(direction:1,at:0)
        var changedFrames=0
        // Compare the old head/ear response with the same pose plus approved
        // eyes. The head warp still runs after the eye texture translation.
        for frame in 0...44 {
            let time=Double(frame)/30,response=head.sample(at:time,allowed:true)
            var pose=CatPose(breath:0.35)
            pose.lookX=response.lookX;pose.rightEar=response.rightEar
            let aim=eyes.sample(at:time)
            for closed in [0.0,0.4,0.92,1.0] {
                pose.eyes=closed;before.update(pose);after.update(pose);after.eyeAim=aim
                let old=bitmap(before),new=bitmap(after),a=data(old),b=data(new)
                check(after.pose==before.pose,"head, ear, body, breath and blink pose must stay identical")
                if aim == .neutral || closed==1 {check(a==b,"neutral and fully closed eyes must remain byte-exact")}
                else if a != b {changedFrames += 1}
                for y in 0..<534 {for x in 0..<580 {
                    // Includes the original <=0.28 head turn, not a wider gaze.
                    let p=CGPoint(x:Double(x)/2,y:Double(y)/2)
                    let eye=CGRect(x:146,y:124,width:25,height:23).contains(p) || CGRect(x:183,y:124,width:26,height:23).contains(p)
                    if !eye {
                        let i=y*new.bytesPerRow+x*4
                        check(a[i..<i+4]==b[i..<i+4],"eye integration changed a non-eye pixel at frame \(frame), \(x),\(y)")
                    }
                }}
                if closed==0 && [0,7,15,28,36,44].contains(frame) {
                    try new.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent("accessory-eyes-\(frame)-290pt.png"))
                }
            }
        }
        check(changedFrames>30,"rendered open-eye journey must actually be visible, not an unwired aim")
        print("PASS 180 integrated 290pt renders: unchanged non-eye pixels, original head/ear pose, blink occlusion, exact neutral/closed return")
    }
}
