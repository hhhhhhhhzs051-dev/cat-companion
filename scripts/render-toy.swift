import AppKit

@main struct ToyRender {
    static func main() throws {
        _=NSApplication.shared
        let output=URL(fileURLWithPath:CommandLine.arguments.dropFirst().first ?? "/tmp/cat-toy-review")
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        let view=try NativeCatView(resources:URL(fileURLWithPath:"src"))
        view.frame=NSRect(x:0,y:0,width:290,height:290*1085/1525+60)
        var toy=CatToy();toy.start(0)
        func capture(_ name:String,_ frame:CatToyFrame) throws {
            view.toyFrame=frame
            var pose=CatPose(lookX:frame.look);pose.paw=PawPose(raise:frame.paw,toyElbow:frame.pawElbow,toyWrist:frame.pawWrist,toySide:frame.pawSide);view.update(pose)
            let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:290,pixelsHigh:267,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
            view.cacheDisplay(in:view.bounds,to:bitmap)
            try bitmap.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent(name+".png"))
        }
        try capture("idle",toy.frame(0.3))
        toy.grab(0.4);toy.move(to:CGPoint(x:0.62,y:0.395),at:0.4);toy.release(0.5)
        _=toy.frame(1)
        for (name,time) in [("approach",1.45),("contact",1.8),("roll",2.15),("settled",2.7)] {try capture(name,toy.frame(time))}
        for (label,point) in [("left",CGPoint(x:0.41,y:0.375)),("right",CGPoint(x:0.77,y:0.435)),("wide-left",CGPoint(x:0.495,y:0.375)),("wide-right",CGPoint(x:0.70,y:0.375)),("near",CGPoint(x:0.605,y:0.405)),("reach",CGPoint(x:0.62,y:0.395)),("inner-left",CGPoint(x:0.57,y:0.395)),("pull-right",CGPoint(x:0.64,y:0.395)),("inner-right",CGPoint(x:0.66,y:0.375))] {
            toy.start(10);toy.grab(11);toy.move(to:point,at:11);toy.release(11.1);_=toy.frame(11.6)
            let plan=CatToyReach(CGPoint(x:point.x,y:CatToy.groundY(point.x)))
            let contactTime=11.6+plan.contactTime
            try capture(label+"-lift",toy.frame(11.88))
            try capture(label+"-prepare",toy.frame(contactTime-0.16))
            try capture(label+"-contact",toy.frame(contactTime))
            try capture(label+"-follow",toy.frame(contactTime+0.12))
            try capture(label+"-roll",toy.frame(13))
        }
        print("Rendered 290pt toy geometry diagnostics; not a live visual acceptance.")
    }
}
