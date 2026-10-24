#if CAT_EYE_VARIATION_STUDY || CAT_EYE_INTERACTION
import CoreImage

// Accepted original-texture pupil rendering, shared by preview and delivery.
struct EyeVariation:Equatable {
    let direction:Double
    let gain:Double
    let pupilWidth:Double
    let fixedAperture:Bool
    let pupilLimit:Double
    init(direction:Double=0,gain:Double=1.125,pupilWidth:Double=1,fixedAperture:Bool=false,pupilLimit:Double=1.25) {
        #if CAT_PUPIL_PLAY_PREVIEW || CAT_PUPIL_PLAY
        let maximum=1.5
        #else
        let maximum=1.4
        #endif
        self.pupilWidth=pupilWidth.isFinite ? max(1,min(maximum,pupilWidth)):1
        self.pupilLimit=self.pupilWidth == 1 ? 1.25:max(self.pupilWidth,pupilLimit.isFinite ? max(1,min(maximum,pupilLimit)):1.25)
        self.direction=self.pupilWidth == 1 && direction.isFinite ? max(-1,min(1,direction)):0
        self.gain=self.direction != 0 && [1.125,1.35,1.5].contains(gain) ? gain:1.125
        self.fixedAperture=fixedAperture && (self.direction != 0 || self.pupilWidth != 1)
    }
    static let neutral=EyeVariation()
}

final class EyeVariationRenderer {
    // Frozen accepted62 aperture calibration; accepted pupil widths use the
    // same original-texture mapping in preview and delivery.
    // Gaze is a rigid translation. Pupil width is a distinct local horizontal
    // resampling: original color/height/tilt, never a painted disc.
    private let kernel=CIWarpKernel(source:"""
    kernel vec2 eyeStudy(float direction,float gain,float pupilWidth,float fixedAperture,float pupilLimit) {
        vec2 p=destCoord();vec2 q=vec2(p.x,1254.0-p.y);
        float isLeft=1.0-step(790.0,q.x);
        float start=mix(846.0,650.0,isLeft),width=mix(72.0,78.0,isLeft);
        float dx=direction*mix(3.0,4.0,isLeft)*gain;
        float limitDx=sign(direction)*mix(3.0,4.0,isLeft)*gain;
        if (pupilWidth>1.0) {
            float center=mix(882.4-0.12*(q.y-537.0),693.5-0.18*(q.y-537.0),isLeft);
            float d=q.x-center;
            float influence=1.0-smoothstep(10.0,29.0,abs(d));
            dx=d-d/(1.0+(pupilWidth-1.0)*influence);
            limitDx=d-d/(1.0+(pupilLimit-1.0)*influence);
        }
        float visible=1.0;
        for (int i=0;i<2;i++) {
            // Same conservative source aperture throughout one journey. The
            // displacement itself stays rigid (gaze) or continuous (width).
            vec2 edge=q-vec2(mix(dx,limitDx,fixedAperture)*float(i),0.0);
            float t=clamp((edge.x-start)/width,0.0,1.0);
            float arc=sqrt(max(0.0,1.0-pow(2.0*t-1.0,2.0)));
            float top=mix(563.0-37.0*(2.0*t-t*t),529.0+29.0*t*t,isLeft);
            float central=mix(smoothstep(850.0,866.0,edge.x)*(1.0-smoothstep(908.0,918.0,edge.x)),
                smoothstep(658.0,674.0,edge.x)*(1.0-smoothstep(706.0,724.0,edge.x)),isLeft);
            float calibrated=mix(525.5+0.0067*pow(edge.x-906.0,2.0),529.0+20.0*t*t,isLeft);
            top=mix(top,calibrated,central);
            float bottom=mix(563.0-37.0*t+23.0*arc,529.0+29.0*t+25.0*arc,isLeft);
            float horizontal=step(start+0.75,edge.x)*(1.0-step(start+width-0.75,edge.x));
            float topInset=i==0 ? 0.75:0.25;
            visible*=horizontal*step(top+topInset,edge.y)*(1.0-step(bottom-0.75,edge.y));
        }
        return visible>0.5 ? p-vec2(dx,0.0):p;
    }
    """)
    func apply(to image:CIImage,state:EyeVariation)->CIImage {
        guard state != .neutral,let kernel else{return image}
        return kernel.apply(extent:image.extent,roiCallback:{_,r in r.insetBy(dx:-8,dy:0)},
            image:image,arguments:[state.direction,state.gain,state.pupilWidth,state.fixedAperture ? 1.0:0.0,state.pupilLimit]) ?? image
    }
}
#endif
