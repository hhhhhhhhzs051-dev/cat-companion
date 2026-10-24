#if CAT_EYE_HANDOFF_PREVIEW || CAT_EYE_HANDOFF
import CoreImage

// Joint coordinate map accepted in the isolated 290pt preview. Single effects use their accepted
// renderers. The original image is sampled once, with fixed destination masks.
// Narrow contract: accessories are on the right, aim.x is in 0...1 and
// fixedApertureX is 1. This is not a general left/right gaze renderer.
final class CatEyeHandoffRenderer {
    private let kernel=CIWarpKernel(source:"""
    float eyeInside(vec2 edge,float isLeft,float inset) {
        float start=mix(846.0,650.0,isLeft),width=mix(72.0,78.0,isLeft);
        float t=clamp((edge.x-start)/width,0.0,1.0);
        float arc=sqrt(max(0.0,1.0-pow(2.0*t-1.0,2.0)));
        float top=mix(563.0-37.0*(2.0*t-t*t),529.0+29.0*t*t,isLeft);
        float central=mix(smoothstep(850.0,866.0,edge.x)*(1.0-smoothstep(908.0,918.0,edge.x)),smoothstep(658.0,674.0,edge.x)*(1.0-smoothstep(706.0,724.0,edge.x)),isLeft);
        float calibrated=mix(525.5+0.0067*pow(edge.x-906.0,2.0),529.0+20.0*t*t,isLeft);
        top=mix(top,calibrated,central);
        float bottom=mix(563.0-37.0*t+23.0*arc,529.0+29.0*t+25.0*arc,isLeft);
        return step(start+0.75,edge.x)*(1.0-step(start+width-0.75,edge.x))*step(top+inset,edge.y)*(1.0-step(bottom-0.75,edge.y));
    }
    float pupilOffset(vec2 q,float isLeft,float width) {
        float center=mix(882.4-0.12*(q.y-537.0),693.5-0.18*(q.y-537.0),isLeft);
        float d=q.x-center,influence=1.0-smoothstep(10.0,29.0,abs(d));
        return d-d/(1.0+(width-1.0)*influence);
    }
    kernel vec2 eyeHandoff(float aim,float gain,float width,float limit) {
        vec2 p=destCoord(),q=vec2(p.x,1254.0-p.y);
        float side=1.0-step(790.0,q.x);
        float extent=mix(3.0,4.0,side)*gain;
        float dest=eyeInside(q,side,0.75);
        float gazeMask=dest*eyeInside(q-vec2(extent,0.0),side,0.25);
        float shift=aim*extent*gazeMask;
        // The width mask stays at the accepted original-pupil boundary. It
        // must not cross binary pixel thresholds as gaze advances.
        float pupilMask=dest*eyeInside(q-vec2(pupilOffset(q,side,limit),0.0),side,0.25);
        float dilation=pupilOffset(q-vec2(shift,0.0),side,width)*pupilMask;
        return p-vec2(shift+dilation,0.0);
    }
    """)
    func apply(to image:CIImage,aim:CatEyeAim,variation:EyeVariation)->CIImage {
        guard let kernel else{return image}
        return kernel.apply(extent:image.extent,roiCallback:{_,r in r.insetBy(dx:-14,dy:0)},image:image,arguments:[aim.x,aim.gain,variation.pupilWidth,variation.pupilLimit]) ?? image
    }
}
#endif
