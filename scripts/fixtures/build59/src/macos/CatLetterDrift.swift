import AppKit
import QuartzCore

enum LetterDriftKind { case petal, leaf }
struct LetterDriftFrame {
    let kind:LetterDriftKind
    let center:CGPoint
    let size:CGSize
    let angle:CGFloat
    let opacity:Float
}

// User-accepted opening from preview 98fbcc3b; trajectories and shapes unchanged.
struct LetterDriftPlan {
    static let duration=2.7
    let bounds:CGRect
    let imageSize:CGSize
    let textRight:CGFloat
    private var imageRect:CGRect? {
        guard bounds.width>0,bounds.height>0,imageSize.width>0,imageSize.height>0 else {return nil}
        let scale=min(1,min(bounds.width/imageSize.width,bounds.height/imageSize.height))
        let size=CGSize(width:imageSize.width*scale,height:imageSize.height*scale)
        return CGRect(x:bounds.midX-size.width/2,y:bounds.midY-size.height/2,width:size.width,height:size.height)
    }
    func sample(piece:Int,at time:Double)->LetterDriftFrame? {
        guard (0..<3).contains(piece),let paper=imageRect else{return nil}
        let scale=paper.width/540
        // At normal size the reader ends at x=512; even the fully rotated
        // decorations stay strictly in the spare 28pt gutter.
        guard paper.maxX-25*scale>textRight+1,paper.height>260*scale else{return nil}
        let delays:[Double]=[0,0.18,0.58]
        let durations:[Double]=[2.40,2.42,2.12]
        // Landmarks on the approved 1269x1240 artwork, in its top-left space:
        // lower-right flower petal, small blossom, terminal leaf tip.
        let origins=[CGPoint(x:1230,y:145),CGPoint(x:1237,y:174),CGPoint(x:1236,y:277)]
        let distances:[CGFloat]=[156,169,145]
        let sizes=[CGSize(width:7,height:10),CGSize(width:6.5,height:9),CGSize(width:6,height:12)]
        let raw=(time-delays[piece])/durations[piece]
        let elapsed=max(0,min(durations[piece],time-delays[piece]))
        let leaf=piece==2
        let releaseDuration=leaf ? 0.18:0.16
        let release=CGFloat(min(1,elapsed/releaseDuration))
        let loosen=release*release*(3-2*release)
        let fall=CGFloat(max(0,(elapsed-releaseDuration)/(durations[piece]-releaseDuration)))
        // Smooth velocity at release. Petals float; the shorter leaf flight
        // has a different acceleration curve and a slightly broader side sway.
        let descent=leaf ? fall*fall*(2-fall):fall*fall*(2.4-1.4*fall)
        let flutter=sin(fall * .pi * (leaf ? 2.2:1.6))*sin(fall * .pi)
        let direction:CGFloat=piece==1 ? -1:1
        let drift=direction*((leaf ? 2.5:1.7)*flutter+0.35*loosen)
        let origin=CGPoint(x:origins[piece].x*540/1269,y:origins[piece].y*540/1269)
        let position=CGPoint(x:paper.minX+(origin.x+drift)*scale,
                             y:paper.minY+(origin.y+0.45*loosen+distances[piece]*descent)*scale)
        let fadeIn=min(1,max(0,elapsed/0.07))
        let fadeOut=min(1,max(0,(1-raw)/0.28))
        let alpha=Float(fadeIn*fadeOut)*(piece==2 ? 0.70:0.68)
        return LetterDriftFrame(kind:piece==2 ? .leaf:.petal,center:position,
            size:CGSize(width:sizes[piece].width*scale,height:sizes[piece].height*scale),
            angle:(leaf ? -0.25:0.18)+direction*0.16*loosen+(leaf ? 0.36:0.23)*flutter,
            opacity:raw>0 && raw<1 ? alpha:0)
    }
    func frames(at time:Double) -> [LetterDriftFrame] {
        guard time>=0,time<Self.duration else{return []}
        return (0..<3).compactMap{sample(piece:$0,at:time)}.filter{$0.opacity>0}
    }
}

private final class LetterDriftCompletion:NSObject,CAAnimationDelegate {
    let finished:()->Void
    init(_ finished:@escaping ()->Void){self.finished=finished}
    func animationDidStop(_ anim:CAAnimation,finished flag:Bool) {if flag {finished()}}
}

// Three compositor-driven layers for one opening. No display link, repeating
// timer, particle emitter, text changes, preferences or network access.
final class LetterDriftView:NSView {
    private(set) var isAnimating=false
    private var completion:LetterDriftCompletion?
    private var generation=0
    override var isFlipped:Bool {true}
    override func hitTest(_ point:NSPoint)->NSView? {nil}
    override init(frame:NSRect) {
        super.init(frame:frame)
        wantsLayer=true
        layer?.masksToBounds=true
        setAccessibilityElement(false)
    }
    required init?(coder:NSCoder){fatalError("init(coder:) has not been implemented")}
    func stop() {
        generation += 1
        completion=nil
        isAnimating=false
        layer?.sublayers?.forEach{$0.removeAllAnimations();$0.removeFromSuperlayer()}
    }
    func play(imageSize:CGSize,textRight:CGFloat,reduced:Bool) {
        stop()
        guard !reduced,window?.isVisible==true else{return}
        let plan=LetterDriftPlan(bounds:bounds,imageSize:imageSize,textRight:textRight)
        guard plan.frames(at:0.8).count==3 else{return}
        let run=generation
        let callback=LetterDriftCompletion{[weak self] in
            guard let self,self.generation==run else{return}
            self.stop()
        }
        completion=callback
        isAnimating=true
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for piece in 0..<3 {
            let first=plan.sample(piece:piece,at:0)!
            let particle=Self.shape(kind:first.kind,size:first.size)
            particle.position=first.center
            particle.opacity=0
            particle.contentsScale=window?.backingScaleFactor ?? 2
            layer!.addSublayer(particle)
            let samples=(0...81).map{plan.sample(piece:piece,at:Double($0)/81*LetterDriftPlan.duration)!}
            let positions=CAKeyframeAnimation(keyPath:"position")
            positions.values=samples.map{NSValue(point:$0.center)}
            let rotations=CAKeyframeAnimation(keyPath:"transform.rotation.z")
            rotations.values=samples.map{NSNumber(value:Double($0.angle))}
            let opacity=CAKeyframeAnimation(keyPath:"opacity")
            opacity.values=samples.map{NSNumber(value:$0.opacity)}
            for animation in [positions,rotations,opacity] {
                animation.duration=LetterDriftPlan.duration
                animation.keyTimes=(0...81).map{NSNumber(value:Double($0)/81)}
            }
            let group=CAAnimationGroup()
            group.animations=[positions,rotations,opacity]
            group.duration=LetterDriftPlan.duration
            group.isRemovedOnCompletion=true
            if piece==2 {group.delegate=callback}
            particle.add(group,forKey:"opening")
        }
        CATransaction.commit()
    }
    private static func shape(kind:LetterDriftKind,size:CGSize)->CAShapeLayer {
        let node=CAShapeLayer()
        node.bounds=CGRect(origin:.zero,size:size)
        let path=CGMutablePath()
        func p(_ x:CGFloat,_ y:CGFloat)->CGPoint {CGPoint(x:x*size.width,y:y*size.height)}
        if kind == .petal {
            path.move(to:p(0.50,0.96))
            path.addCurve(to:p(0.08,0.31),control1:p(0.12,0.81),control2:p(-0.03,0.53))
            path.addCurve(to:p(0.54,0.08),control1:p(0.13,0.07),control2:p(0.41,0.00))
            path.addCurve(to:p(0.92,0.43),control1:p(0.84,0.01),control2:p(1.01,0.22))
            path.addCurve(to:p(0.50,0.96),control1:p(0.84,0.69),control2:p(0.72,0.85))
            node.fillColor=NSColor(srgbRed:0.91,green:0.74,blue:0.68,alpha:1).cgColor
            node.strokeColor=NSColor(srgbRed:0.64,green:0.48,blue:0.38,alpha:0.52).cgColor
        } else {
            path.move(to:p(0.50,0.03))
            path.addCurve(to:p(0.50,0.97),control1:p(1.05,0.25),control2:p(0.99,0.69))
            path.addCurve(to:p(0.50,0.03),control1:p(0.02,0.74),control2:p(-0.02,0.30))
            node.fillColor=NSColor(srgbRed:0.64,green:0.73,blue:0.42,alpha:1).cgColor
            node.strokeColor=NSColor(srgbRed:0.36,green:0.47,blue:0.26,alpha:0.72).cgColor
            let vein=CAShapeLayer(),line=CGMutablePath()
            line.move(to:p(0.50,0.15));line.addQuadCurve(to:p(0.49,0.84),control:p(0.66,0.51))
            vein.path=line;vein.strokeColor=node.strokeColor;vein.fillColor=nil
            vein.lineWidth=0.45
            node.addSublayer(vein)
        }
        path.closeSubpath()
        node.path=path;node.lineWidth=0.6;node.lineJoin = .round
        return node
    }
}
