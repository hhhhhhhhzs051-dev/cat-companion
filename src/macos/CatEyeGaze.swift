#if CAT_EYE_GAZE_PREVIEW || CAT_ACCESSORY_GAZE
import CoreImage

// Eye-in-head direction, deliberately separate from CatPose.lookX (head turn).
// Positive x/y means screen right/down in the original 1254px artwork.
struct CatEyeAim: Equatable {
    let x: Double
    let y: Double
    // Animation may use one conservative aperture for its whole journey,
    // avoiding a binary edge switching between texels at intermediate aims.
    let fixedApertureX: Double?
    let gain:Double
    init(x: Double = 0, y: Double = 0, fixedApertureX: Double? = nil, gain:Double = 1) {
        self.x = x.isFinite ? max(-1, min(1, x)) : 0
        self.y = y.isFinite ? max(-1, min(1, y)) : 0
        // Only the two validated amplitudes; neutral remains canonical.
        #if CAT_EYE_INTERACTION_PREVIEW || CAT_EYE_INTERACTION
        self.gain = self.x != 0 && [1.125,1.5].contains(gain) ? gain:1
        #else
        self.gain = self.x != 0 && gain == 1.125 ? 1.125:1
        #endif
        if let limit = fixedApertureX, limit.isFinite, abs(limit) <= 1,
           self.x != 0, limit * self.x > 0, abs(limit) >= abs(self.x) {
            self.fixedApertureX = limit
        } else { self.fixedApertureX = nil }
    }
    static let neutral = CatEyeAim()
}

// Rigid eye renderer shared by the accepted studies and explicit accessory
// glances. Neutral, closed eyes and other interactions keep their original path.
final class CatEyeGazeRenderer {
    // Static horizontal study: translate the original eye texture as a whole.
    // Do not attenuate the translation vector near the lids: that bent pupils.
    // Both the destination and translated source must remain inside the
    // original aperture. An uncovered sliver keeps its original pixels; no
    // inpainting, stretch, mirroring, new iris or reconstructed eyeball.
    private let kernel=CIWarpKernel(source:"""
    kernel vec2 eyeDirection(float aimX, float apertureX, float gain) {
        vec2 p=destCoord();vec2 q=vec2(p.x,1254.0-p.y);
        float isLeft=1.0-step(790.0,q.x);
        float start=mix(846.0,650.0,isLeft);
        float width=mix(72.0,78.0,isLeft);
        // Independently calibrated source-pixel offsets, NOT gaze angles.
        float dx=aimX*mix(3.0,4.0,isLeft)*gain;
        float apertureDx=apertureX*mix(3.0,4.0,isLeft)*gain;
        float visible=1.0;
        for (int i=0;i<2;i++) {
            vec2 edge=q-vec2(apertureDx*float(i),0.0);
            float t=clamp((edge.x-start)/width,0.0,1.0);
            float arc=sqrt(max(0.0,1.0-pow(2.0*t-1.0,2.0)));
            float top=mix(563.0-37.0*(2.0*t-t*t),529.0+29.0*t*t,isLeft);
            // The former conservative boundary excluded visible upper iris,
            // leaving old pupil fragments behind. Calibrate that inner edge
            // from the original pixels, while keeping both corners fixed.
            float central=mix(smoothstep(850.0,866.0,edge.x)*(1.0-smoothstep(908.0,918.0,edge.x)),
                              smoothstep(658.0,674.0,edge.x)*(1.0-smoothstep(706.0,724.0,edge.x)),isLeft);
            float calibrated=mix(525.5+0.0067*pow(edge.x-906.0,2.0),529.0+20.0*t*t,isLeft);
            top=mix(top,calibrated,central);
            float bottom=mix(563.0-37.0*t+23.0*arc,529.0+29.0*t+25.0*arc,isLeft);
            // Binary visibility, NOT a variable displacement or crossfade.
            // The normal native raster's downsampling antialiases this mask.
            float horizontal=step(start+0.75,edge.x)*(1.0-step(start+width-0.75,edge.x));
            // Keep the visible lid conservative, but allow the original
            // antialiased inner-edge texels as source material. Applying the
            // larger upper destination inset to the source left old pupil
            // specks. Lower-edge source coverage must remain unchanged.
            float topInset=i==0 ? 0.75:0.25;
            float vertical=step(top+topInset,edge.y)*(1.0-step(bottom-0.75,edge.y));
            visible*=horizontal*vertical;
        }
        return visible>0.5 ? p-vec2(dx,0.0):p;
    }
    """)
    func apply(to image: CIImage, aim: CatEyeAim) -> CIImage {
        // Vertical gaze is deliberately not part of this static acceptance.
        guard aim.x != 0, let kernel else{return image}
        // Coordinate-only selection avoids a colour-kernel round trip through
        // translucent fur. Outside the two apertures the coordinate is exact.
        return kernel.apply(extent:image.extent,
            roiCallback:{_,r in r.insetBy(dx:-6,dy:0)},
            image:image,arguments:[aim.x,aim.fixedApertureX ?? aim.x,aim.gain]) ?? image
    }
}
#endif
