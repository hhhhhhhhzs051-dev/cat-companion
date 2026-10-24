import AppKit

private final class PaletteProbe: NSView {
    let reward:CatGrowthReward,angle:Double,previous:Bool,accepted:Bool
    init(size:CGFloat,reward:CatGrowthReward,angle:Double,previous:Bool,accepted:Bool=false) {
        self.reward=reward;self.angle=angle;self.previous=previous;self.accepted=accepted
        super.init(frame:NSRect(x:0,y:0,width:size,height:size))
    }
    required init?(coder:NSCoder) {fatalError("unused")}
    override var isFlipped:Bool {true}
    override func draw(_ dirtyRect:NSRect) {
        if accepted {PairPreviewGoldfishArt.draw(reward,in:bounds,sway:angle)}
        else if previous {PairPreviewPeachArt.draw(reward,in:bounds,sway:angle)}
        else {CatGrowthArt.draw(reward,in:bounds,sway:angle)}
    }
}

func runAccessoryPaletteTests() {
    for size in [42.5*200/290,42.5,42.5*440/290,40] {for scale in [1.0,2.0] {for angle in [-0.11,0,0.11] {
        for reward in [CatGrowthReward.flower,.fish,.sageBall] {
            func render(_ previous:Bool,accepted:Bool=false)->NSBitmapImageRep {
                let view=PaletteProbe(size:size,reward:reward,angle:angle,previous:previous,accepted:accepted)
                let b=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:Int(ceil(size*scale)),pixelsHigh:Int(ceil(size*scale)),bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
                b.size=view.bounds.size;view.cacheDisplay(in:view.bounds,to:b);return b
            }
            let old=render(true),next=render(false),accepted=render(false,accepted:true)
            var changed=0,changedCenter=0
            for y in 0..<next.pixelsHigh {for x in 0..<next.pixelsWide {
                let index=y*next.bytesPerRow+x*4
                let a=old.bitmapData!,b=next.bitmapData!
                let frozen=accepted.bitmapData!
                precondition(frozen[index+3]==b[index+3],"all current silhouettes remain exact against the last preview")
                if reward != .fish {precondition((0..<4).allSatisfy{frozen[index+$0]==b[index+$0]},"accepted flower and green ball remain byte-identical")}
                let equal=(0..<4).allSatisfy {a[index+$0]==b[index+$0]}
                if reward == .fish {
                    let px=(Double(x)+0.5)/Double(next.pixelsWide)*40-20
                    let py=(Double(y)+0.5)/Double(next.pixelsHigh)*40-2
                    let qx=cos(angle)*px+sin(angle)*py+20
                    let qy = -sin(angle)*px+cos(angle)*py+2
                    if !equal {
                        changed+=1
                        precondition(qx>1.5 && qx<36.5 && qy>9.5 && qy<36.5,"goldfish redraw stays below the unchanged cord in the original ornament footprint")
                    }
                    continue
                }
                precondition(a[index+3]==b[index+3],"flower and ball keep exact silhouette and alpha")
                if reward == .sageBall {precondition(equal,"green ball remains byte-identical");continue}
                // Invert the existing rotation about the stem/pot joint. Only
                // the petals and center around (20.5,12.5) may change, including AA.
                let px=(Double(x)+0.5)/Double(next.pixelsWide)*40-20
                let py=(Double(y)+0.5)/Double(next.pixelsHigh)*40-28
                let qx=cos(angle)*px+sin(angle)*py+20
                let qy = -sin(angle)*px+cos(angle)*py+28
                let distance=hypot(qx-20.5,qy-12.5)
                if !equal {changed+=1;precondition(distance<10.5,"flower-head palette must not recolor leaves, stem or pot")}
                if distance<1 {changedCenter+=1;precondition(!equal,"requested yellow center must differ from the old ochre")}
            }}
            if reward == .flower {
                precondition(changed>10 && changedCenter>0,"comparison must exercise both the petals and center")
                if angle==0 {
                    let color=next.colorAt(x:Int(25.5/40*Double(next.pixelsWide)),y:Int(12.5/40*Double(next.pixelsHigh)))!.usingColorSpace(.deviceRGB)!
                    precondition(color.redComponent>color.blueComponent && color.blueComponent>color.greenComponent && color.redComponent-color.greenComponent>0.2,"petals have a more saturated pink hue, not pale pink")
                    let center=next.colorAt(x:Int(20.5/40*Double(next.pixelsWide)),y:Int(12.5/40*Double(next.pixelsHigh)))!.usingColorSpace(.deviceRGB)!
                    precondition(center.redComponent>center.greenComponent && center.greenComponent-center.blueComponent>0.25 && center.redComponent-center.greenComponent<0.25,"flower center is yellow, not the previous muted ochre")
                }
            } else if reward == .fish {
                precondition(changed>8,"goldfish is visibly different from the old coral fish")
                if angle==0 {
                    let body=next.colorAt(x:Int(29.0/40*Double(next.pixelsWide)),y:Int(25.0/40*Double(next.pixelsHigh)))!.usingColorSpace(.deviceRGB)!
                    precondition(body.redComponent-body.greenComponent>0.25 && body.redComponent-body.blueComponent>0.25,"goldfish body is red")
                    let oldBody=accepted.colorAt(x:Int(29.0/40*Double(accepted.pixelsWide)),y:Int(25.0/40*Double(accepted.pixelsHigh)))!.usingColorSpace(.deviceRGB)!
                    func saturation(_ c:NSColor)->CGFloat {
                        let hi=max(c.redComponent,max(c.greenComponent,c.blueComponent)),lo=min(c.redComponent,min(c.greenComponent,c.blueComponent))
                        return (hi-lo)/hi
                    }
                    precondition(saturation(body)<saturation(oldBody)-0.12,"goldfish red is materially softer, not just darker")
                    if size==40 && scale==2 {
                        for p in [(6,16),(6,31),(20,12),(21,32)] {
                            precondition(next.colorAt(x:p.0*2,y:p.1*2)!.alphaComponent>0.1,"split tail, dorsal and lower fins remain visible")
                        }
                    }
                }
            }
        }
    }}}
    print("PASS softer goldfish palette: accepted flower/ball pixels exact; all silhouettes unchanged; lower red saturation, cord/hinge and split-tail geometry preserved across sizes/scales/sway")
}
