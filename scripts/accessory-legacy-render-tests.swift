import AppKit

// Production must exactly match the user-approved b25cb99f pair preview.
func runMenuTests(_ app:PetApp) {
    NSApp.finishLaunching()
    for width in [200.0,290,440] {for scale in [1.0,2.0] {for selection: Set<CatGrowthReward> in [[],[.flower],[.fish],[.flower,.fish]] {
        let frame=NSRect(x:0,y:0,width:width,height:60+width*1085/1525)
        let next=CatGrowthAccessoryView(frame:frame),old=AcceptedPairView(frame:frame)
        next.selections=selection;old.selections=selection
        func pixels(_ view:NSView)->Data {
            let b=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:Int(ceil(frame.width*scale)),pixelsHigh:Int(ceil(frame.height*scale)),bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
            b.size=frame.size;view.cacheDisplay(in:view.bounds,to:b)
            return Data(bytes:b.bitmapData!,count:b.bytesPerRow*b.pixelsHigh)
        }
        precondition(pixels(next)==pixels(old),"production decoration pixels must match the approved pair preview")
        for time in [1.05,1.12,1.3,1.7,2.5,3.0] {
            if time == 1.05 {for reward in selection {next.tap(reward,at:1,reduced:false);old.tap(reward,at:1,reduced:false)}}
            next.advance(to:time,enabled:true,reduced:false);old.advance(to:time,enabled:true,reduced:false)
            precondition(pixels(next)==pixels(old),"production motion pixels and timing match approved preview for both independent items")
        }
    }}}
    print("PASS formal rendering isolation: exact approved pair preview flower/fish pixels at 200/290/440pt and 1x/2x")
}
