#if CAT_PAW_EXPERIMENT
import AppKit
import CoreImage

// Experimental local sampling only; never draw the generated face/body/bed.
final class CatPawArt {
    private let image:NSImage
    private lazy var source:CIImage? = makeSource()
    private let bend=CIWarpKernel(source:"""
    kernel vec2 pawBend(float elbow, float wrist) {
        vec2 p=destCoord();vec2 q=vec2(p.x,1254.0-p.y);
        vec2 d=q-vec2(605.0,850.0);
        q=vec2(605.0,850.0)+vec2(cos(elbow)*d.x+sin(elbow)*d.y,-sin(elbow)*d.x+cos(elbow)*d.y);
        float w=smoothstep(-20.0,30.0,dot(q-vec2(753.0,792.0),vec2(0.594,-0.804)));
        float a=wrist*w;d=q-vec2(753.0,792.0);
        q=vec2(753.0,792.0)+vec2(cos(a)*d.x+sin(a)*d.y,-sin(a)*d.x+cos(a)*d.y);
        return vec2(q.x,1254.0-q.y);
    }
    """)
    init(referenceURL:URL)throws {
        guard let value=NSImage(contentsOf:referenceURL),value.isValid else{throw NSError(domain:"CatPawAssets",code:1)}
        image=value
    }
    func overlay(_ pose:PawPose)->CIImage? {
        guard pose.raise>0,let source else{return nil}
        let rig=CatPawRig(raise:pose.raise,lift:pose.lift,elbow:pose.toyElbow,wrist:pose.toyWrist)
        guard let bent=bend?.apply(extent:source.extent,roiCallback:{_,_ in source.extent},image:source,arguments:[rig.elbowAngle,rig.wristAngle]) else{return nil}
        if pose.toySide != 0 {
            // Only screen right uses the mirrored cat-left paw. This horizontal
            // reflection is identical in CI and the planner's coordinates.
            let transform=CatToyFrame.pawTransform(pose.toySide)
            return bent.transformed(by:transform).cropped(to:source.extent)
        }
        return bent.transformed(by:CGAffineTransform(translationX:pose.offsetX,y:0))
    }
    private func makeSource()->CIImage? {
        let layer=NSImage(size:NSSize(width:1254,height:1254),flipped:true){[self] _ in
            let ctx=NSGraphicsContext.current!.cgContext
            ctx.saveGState()
            let path=NativeCatView.path("M605 823 C650 782 705 758 751 725 C765 712 776 709 791 710 C813 708 834 725 843 742 C851 766 831 789 805 798 C780 809 753 815 740 831 Z")
            ctx.addPath(path);ctx.clip()
            image.draw(in:NSRect(x:0,y:0,width:1254,height:1254),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:[.interpolation:NSImageInterpolation.high])
            ctx.restoreGState();return true
        }
        guard let data=layer.tiffRepresentation else{return nil}
        return CIImage(data:data)
    }
}
#endif
