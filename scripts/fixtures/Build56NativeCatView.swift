import AppKit
import CoreImage

// Lazy, view-local cache of already rendered idle frames. No animation is precomputed.
// The budget covers retained bitmap bytes; CI's transient working memory is separate.
final class Build56IdleFrameCache {
    let byteLimit:Int
    private var images:[Int:CGImage]=[:]
    private var recency:[Int]=[]
    private var scale:Double?
    private(set) var byteCount=0
    var count:Int {images.count}
    init(byteLimit:Int=64*1024*1024) {self.byteLimit=max(0,byteLimit)}
    func removeAll() {images.removeAll();recency.removeAll();byteCount=0;scale=nil}
    func prepare(scale value:Double) {
        if scale != value {removeAll();scale=value}
    }
    func image(for key:Int)->CGImage? {
        guard let image=images[key] else{return nil}
        recency.removeAll{$0==key};recency.append(key)
        return image
    }
    func insert(_ image:CGImage,for key:Int) {
        guard (0...48).contains(key) else{return}
        let cost=image.bytesPerRow*image.height
        if let previous=images.removeValue(forKey:key) {byteCount-=previous.bytesPerRow*previous.height}
        recency.removeAll{$0==key}
        guard cost<=byteLimit else{return}
        while byteCount+cost>byteLimit,let oldest=recency.first {
            recency.removeFirst()
            if let removed=images.removeValue(forKey:oldest) {byteCount-=removed.bytesPerRow*removed.height}
        }
        images[key]=image;recency.append(key);byteCount+=cost
    }
}

// The same immutable image + path + displayed transform feed drawing and hit testing.
final class Build56NativeCatView:NSView {
    override var isFlipped:Bool {true}
    private var cat:NSImage!
    private var closed:NSImage!
    private var bed:NSImage!
    private var catPath:CGPath!
    private var bedPath:CGPath!
    private var frontPath:CGPath!
    private(set) var pose = CatPose()
    var useV1Rendering=false {didSet{needsDisplay=true}}
    var growthBallTint: NSColor? { didSet { needsDisplay = true } }
    private var isolated:CIImage!
    private var closedCI:CIImage!
    private var fullClosedCI:CIImage!
    private var cachedImage:CGImage?
    private let idleFrames=Build56IdleFrameCache()
    #if CAT_RENDER_TEST
    var renderedCatImage:CGImage? {cachedImage}
    var idleCacheBytes:Int {idleFrames.byteCount}
    var idleCacheCount:Int {idleFrames.count}
    #endif
    private var cachedMouthImage:CGImage?
    private var cachedKey:[Double]=[]
    var cacheEnabled=true
    var mouthArt:CatMouthArt?
    #if CAT_PAW_EXPERIMENT
    var pawArt:CatPawArt?
    private var cachedPawImage:CGImage?
    private var cachedGroomEyesImage:CGImage?
    var pawPose=PawPose() {didSet{if pawPose != oldValue {needsDisplay=true}}}
    #endif
    var mouthPose=MouthPose() {didSet{if mouthPose != oldValue {needsDisplay=true}}}
    private let eyelids=CIKernel(source:"""
    kernel vec4 eyelids(sampler original, sampler shut, float closure) {
        vec2 p=destCoord();vec2 q=vec2(p.x,1254.0-p.y);
        vec4 base=sample(original,samplerTransform(original,p));
        float left=1.0-smoothstep(0.8,1.0,length((q-vec2(685.0,551.0))/vec2(78.0,40.0)));
        float right=1.0-smoothstep(0.8,1.0,length((q-vec2(882.0,551.0))/vec2(57.0,39.0)));
        float t=clamp(q.x<790.0 ? (q.x-640.0)/110.0:(q.x-836.0)/89.0,0.0,1.0);
        float arc=sqrt(max(0.0,1.0-pow(2.0*t-1.0,2.0)));
        float top=q.x<790.0 ? 528.0+39.0*t*t:570.0-44.0*(2.0*t-t*t);
        float bottom=q.x<790.0 ? 528.0+39.0*t+20.0*arc:570.0-44.0*t+19.0*arc;
        float line=q.x<790.0 ? 539.0+43.0*pow(clamp((q.x-621.0)/129.0,0.0,1.0),1.5):580.0-43.0*pow(clamp((q.x-835.0)/100.0,0.0,1.0),0.6);
        float upper=mix(top,line,closure),lower=mix(bottom,line,closure);
        float above=1.0-smoothstep(upper-1.0,upper+1.0,q.y),below=smoothstep(lower-1.0,lower+1.0,q.y);
        float shift=q.y<line ? line-upper:line-lower;
        vec4 lid=sample(shut,samplerTransform(shut,vec2(q.x,1254.0-q.y-shift)));
        float reveal=max(above,below)*smoothstep(0.0,0.16,closure);
        float finish=smoothstep(0.93,1.0,closure);
        lid=mix(lid,sample(shut,samplerTransform(shut,p)),finish);
        return mix(base,lid,max(left,right)*mix(reveal,1.0,finish));
    }
    """)
    private let imageContext=CIContext(options:[.cacheIntermediates:false])
    // Warp the alpha silhouette and original pixels together. No cut patches or replacement art.
    private let warp=CIWarpKernel(source:"""
    kernel vec2 micro(float breath, float leftEar, float rightEar, float head, float grooming, float jaw, float look) {
        vec2 p=destCoord();
        vec2 q=vec2(p.x,1254.0-p.y);
        float face=smoothstep(420.0,550.0,q.x)*(1.0-smoothstep(mix(655.0,715.0,grooming),mix(815.0,760.0,grooming),q.y));
        q.y-=head*2.2*face;
        q.x-=look*18.0*face;
        float a=(head*0.0045+look*0.018)*face;
        vec2 d=q-vec2(790.0,670.0);
        q=vec2(790.0,670.0)+vec2(cos(a)*d.x+sin(a)*d.y,-sin(a)*d.x+cos(a)*d.y);
        // Continuous displacement of original chin pixels; nose/eyes/neck are fixed.
        float chin=smoothstep(695.0,710.0,q.y)*(1.0-smoothstep(740.0,790.0,q.y))*(1.0-smoothstep(35.0,95.0,abs(q.x-798.0)));
        q.y-=6.0*clamp(jaw,0.0,1.0)*chin;
        float lw=(1.0-smoothstep(335.0,425.0,q.y))*(1.0-smoothstep(90.0,180.0,abs(q.x-520.0)));
        float rw=(1.0-smoothstep(325.0,418.0,q.y))*(1.0-smoothstep(80.0,160.0,abs(q.x-995.0)));
        a=leftEar*0.025*lw;d=q-vec2(545.0,397.0);
        q=vec2(545.0,397.0)+vec2(cos(a)*d.x+sin(a)*d.y,-sin(a)*d.x+cos(a)*d.y);
        a=-rightEar*0.022*rw;d=q-vec2(980.0,385.0);
        q=vec2(980.0,385.0)+vec2(cos(a)*d.x+sin(a)*d.y,-sin(a)*d.x+cos(a)*d.y);
        float body=(1.0-smoothstep(0.0,1.0,length((q-vec2(330.0,580.0))/330.0)))*(1.0-smoothstep(450.0,560.0,q.x))*(1.0-smoothstep(710.0,805.0,q.y));
        q.x-=breath*body*(q.x-330.0)*0.004;
        q.y-=breath*body*(q.y-730.0)*0.011;
        return vec2(q.x,1254.0-q.y);
    }
    """)
    private(set) var catTransform=CGAffineTransform.identity
    private var reportedText = ""
    private var textVisibilityProbe: NSWindow?
    var text="" {didSet {
        if text != oldValue {reportedText="";needsDisplay=true;setAccessibilityValue(text)}
        updateTextVisibilityProbe()
    }}
    var needsTextReceipt: ((String)->Bool)?
    var onTextRendered: ((String)->Void)?
    var onPet:(()->Void)?
    var onToyKey:((UInt16)->Bool)?
    var toyFrame=CatToyFrame() {didSet{if toyFrame != oldValue {needsDisplay=true}}}
    var toyGuide:ClosedRange<Double>? {didSet{if toyGuide != oldValue {needsDisplay=true}}}
    override var acceptsFirstResponder:Bool {true}
    init(resources:URL) throws {
        super.init(frame:.zero)
        func image(_ name:String)throws->NSImage {
            guard let img=NSImage(contentsOf:resources.appendingPathComponent("assets/"+name)),img.isValid else {throw NSError(domain:"CatAssets",code:1,userInfo:[NSLocalizedDescriptionKey:"缺少或无法读取图片："+name])};return img
        }
        cat=try image("cat-d.png");bed=try image("bed-complete-v2.png")
        mouthArt=try CatMouthArt(textureURL:resources.appendingPathComponent("assets/cat-tongue-v1.png"))
        #if CAT_PAW_EXPERIMENT
        pawArt=try? CatPawArt(referenceURL:resources.appendingPathComponent("assets/cat-paw-contact-v1.png"))
        #endif
        let original=try image("cat-closed.png")
        // Convert the accepted SVG's soft elliptical eye masks once; no AI redraw or frame crossfade.
        let size=NSSize(width:1254,height:1254)
        let mask=NSImage(size:size,flipped:true){_ in
            NSColor.white.setFill()
            NSBezierPath(ovalIn:NSRect(x:610,y:517,width:150,height:68)).fill()
            NSBezierPath(ovalIn:NSRect(x:829,y:518,width:106,height:66)).fill()
            return true
        }
        guard let sourceData=original.tiffRepresentation,let maskData=mask.tiffRepresentation,
              let source=CIImage(data:sourceData),let matte=CIImage(data:maskData),
              let composite=CIFilter(name:"CIBlendWithAlphaMask",parameters:[kCIInputImageKey:source,kCIInputBackgroundImageKey:CIImage(color:.clear).cropped(to:source.extent),kCIInputMaskImageKey:matte.applyingFilter("CIGaussianBlur",parameters:[kCIInputRadiusKey:4])])?.outputImage,
              let cg=CIContext(options:[.useSoftwareRenderer:false]).createCGImage(composite,from:source.extent) else {throw NSError(domain:"CatAssets",code:2)}
        closed=NSImage(cgImage:cg,size:size)
        catPath=Self.path("M87 744 C103 669 120 575 156 492 C190 407 256 364 334 338 C389 321 438 316 486 319 L479 217 C498 206 549 247 598 270 L634 264 L654 274 L675 267 L697 279 L727 274 L751 288 L777 280 L805 287 C864 278 971 231 1039 190 C1043 233 1017 305 1005 354 C1052 444 1080 535 1096 647 C1100 696 1094 749 1079 784 C811 836 363 824 87 744 Z")
        bedPath=Self.path("M42 375 C42 82 1488 82 1488 375 L1488 726 C1488 1004 42 1004 42 726 Z")
        frontPath=Self.path("M-98 625 C-98 872 1348 872 1348 625 L1348 1274 L-98 1274 Z")
        // A single transparent, full-resolution V1 layer prevents sampling the beige background.
        let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1254,pixelsHigh:1254,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
        let ctx=NSGraphicsContext.current!.cgContext
        ctx.translateBy(x:0,y:1254);ctx.scaleBy(x:1,y:-1);ctx.addPath(catPath);ctx.clip()
        NSGraphicsContext.current=NSGraphicsContext(cgContext:ctx,flipped:true)
        cat.draw(in:NSRect(x:0,y:0,width:1254,height:1254),from:.zero,operation:.copy,fraction:1,respectFlipped:true,hints:nil)
        NSGraphicsContext.restoreGraphicsState()
        isolated=CIImage(cgImage:bitmap.cgImage!)
        closedCI=CIImage(data:closed.tiffRepresentation!)
        fullClosedCI=source
        guard warp != nil && eyelids != nil else{throw NSError(domain:"CatWarp",code:1)}
        setAccessibilityElement(true);setAccessibilityRole(.button);setAccessibilityLabel("摸摸猫的头")
    }
    required init?(coder:NSCoder){fatalError("init(coder:) not used")}
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        idleFrames.removeAll();cachedKey=[];needsDisplay=true
    }
    private var canCacheIdleFrame:Bool {
        // cachedImage contains the cat only. Bed, guide and ball are composited
        // afterwards, so a resting toy does not invalidate breathing bitmaps.
        guard cacheEnabled,!useV1Rendering,
              pose==CatPose(breath:pose.breath),mouthPose==MouthPose(),
              pose.breath.isFinite,(0...1).contains(pose.breath) else{return false}
        #if CAT_PAW_EXPERIMENT
        guard pawPose==PawPose() else{return false}
        #endif
        return true
    }
    override func accessibilityPerformPress()->Bool {onPet?();return true}
    override func keyDown(with event:NSEvent) {
        if onToyKey?(event.keyCode)==true {return}
        if event.keyCode==49 || event.keyCode==36 {onPet?()}else{super.keyDown(with:event)}
    }
    static func path(_ string:String)->CGPath {
        let regex=try! NSRegularExpression(pattern:"[MCLZ]|-?[0-9]+(?:\\.[0-9]+)?")
        let tokens=regex.matches(in:string,range:NSRange(string.startIndex...,in:string)).map{String(string[Range($0.range,in:string)!])}
        let path=CGMutablePath();var i=0
        func point()->CGPoint {let p=CGPoint(x:Double(tokens[i])!,y:Double(tokens[i+1])!);i+=2;return p}
        while i<tokens.count {let op=tokens[i];i+=1
            switch op {case "M":path.move(to:point());case "L":path.addLine(to:point());case "C":let a=point(),b=point(),c=point();path.addCurve(to:c,control1:a,control2:b);case "Z":path.closeSubpath();default:preconditionFailure("Unsupported artwork path")}
        };return path
    }
    func update(_ value:(eyes:Double,breath:Double,lean:Double)) {
        update(CatPose(eyes:value.eyes,breath:value.breath,lean:value.lean))
    }
    func update(_ value:CatPose) {
        guard pose != value else{return}
        pose=value
        mouthPose=value.mouth
        #if CAT_PAW_EXPERIMENT
        pawPose=value.paw
        #endif
        catTransform=CGAffineTransform(translationX:690,y:800-value.breath*2-value.lean*2.5).rotated(by:-value.lean*0.32 * .pi/180).scaledBy(x:1,y:1+value.breath*0.006).translatedBy(x:-690,y:-800)
        needsDisplay=true
    }
    private func drawBed(_ ctx:CGContext) {
        ctx.saveGState();ctx.translateBy(x:-140,y:250);ctx.addPath(bedPath);ctx.clip()
        bed.draw(in:NSRect(x:0,y:0,width:1536,height:1024),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:[.interpolation:NSImageInterpolation.high]);ctx.restoreGState()
    }
    override func draw(_ dirtyRect:NSRect) {
        NSColor.clear.setFill();dirtyRect.fill(using:.copy)
        guard let ctx=NSGraphicsContext.current?.cgContext else{return}
        ctx.saveGState();ctx.translateBy(x:0,y:60);ctx.scaleBy(x:bounds.width/1525,y:bounds.width/1525);ctx.translateBy(x:135,y:-165)
        drawBed(ctx)
        ctx.saveGState()
        if !useV1Rendering {
            // Eye closure is composited before warping so feedback follows the face exactly.
            let scale=min(1,bounds.width*(window?.backingScaleFactor ?? 2)/1525)
            idleFrames.prepare(scale:Double(scale))
            // Reuse subpixel-identical renders; do not quantize interaction timing or hit geometry.
            var key=[(pose.eyes*256).rounded()/256,(pose.breath*48).rounded()/48,(pose.leftEar*256).rounded()/256,(pose.rightEar*256).rounded()/256,(pose.head*256).rounded()/256,Double(scale),mouthPose.extensionAmount,mouthPose.curl,pose.groomingProfile ? 1:0]
            key.append(mouthPose.opening)
            #if CAT_PAW_EXPERIMENT
            key.append(contentsOf:[pawPose.raise,pawPose.offsetX,pawPose.lift,mouthPose.grooming ? 1:0,mouthPose.sweep,mouthPose.fold])
            key.append(contentsOf:[pawPose.toyElbow ?? -10,pawPose.toyWrist])
            key.append(Double(pawPose.toySide))
            #endif
            key.append(pose.lookX)
            if !cacheEnabled || key != cachedKey {
                var source=key[0]>0 ? eyelids!.apply(extent:isolated.extent,roiCallback:{_,r in r.insetBy(dx:0,dy:-60)},arguments:[isolated!,fullClosedCI!,key[0]])! : isolated!
                #if CAT_PAW_EXPERIMENT
                cachedGroomEyesImage=nil
                if key[0]>0 && pose.groomingProfile {
                    // Rasterize only the eye patch separately. Compositing in CI still resamples
                    // the entire silhouette and alters low-alpha fur pixels outside the eye region.
                    let eyeRegion=CGRect(x:600,y:654,width:350,height:105)
                    let eyeLayer=source.cropped(to:eyeRegion)
                    let moved=warp!.apply(extent:isolated.extent,roiCallback:{_,r in r.insetBy(dx:-40,dy:-20)},image:eyeLayer,arguments:[key[1],key[2],key[3],key[4],key[8],0,pose.lookX])!
                    let layer=moved.transformed(by:CGAffineTransform(scaleX:scale,y:scale))
                    cachedGroomEyesImage=imageContext.createCGImage(layer,from:layer.extent)
                    source=isolated
                }
                #endif
                // Use precisely the existing quantized breath value, never a new timeline.
                let idleKey=canCacheIdleFrame ? Int((key[1]*48).rounded()):-1
                if canCacheIdleFrame,let image=idleFrames.image(for:idleKey) {
                    cachedImage=image
                } else {
                    let result=warp!.apply(extent:isolated.extent,roiCallback:{_,r in r.insetBy(dx:-40,dy:-20)},image:source,arguments:[key[1],key[2],key[3],key[4],key[8],mouthPose.opening,pose.lookX])!
                    let sized=result.transformed(by:CGAffineTransform(scaleX:scale,y:scale))
                    cachedImage=imageContext.createCGImage(sized,from:sized.extent)
                    if canCacheIdleFrame,let image=cachedImage {idleFrames.insert(image,for:idleKey)}
                }
                cachedKey=key
                #if CAT_PAW_EXPERIMENT
                cachedPawImage=nil
                if let paw=pawArt?.overlay(pawPose),let moved=warp!.apply(extent:isolated.extent,roiCallback:{_,r in r.insetBy(dx:-12,dy:-12)},image:paw,arguments:[key[1],key[2],key[3],key[4],key[8],0,0]) {
                    let layer=moved.transformed(by:CGAffineTransform(scaleX:scale,y:scale))
                    cachedPawImage=imageContext.createCGImage(layer,from:layer.extent)
                }
                #endif
                // Keep the original silhouette sampling identical with/without a mouth action.
                cachedMouthImage=nil
                if let mouth=mouthArt?.overlay(mouthPose),let moved=warp!.apply(extent:isolated.extent,roiCallback:{_,r in r.insetBy(dx:-40,dy:-20)},image:mouth,arguments:[key[1],key[2],key[3],key[4],key[8],0,pose.lookX]) {
                    let layer=moved.transformed(by:CGAffineTransform(scaleX:scale,y:scale))
                    cachedMouthImage=imageContext.createCGImage(layer,from:layer.extent)
                }
            }
            if let cg=cachedImage {
                let lean=catLeanTransform
                ctx.concatenate(lean)
                NSImage(cgImage:cg,size:NSSize(width:1254,height:1254)).draw(in:NSRect(x:0,y:0,width:1254,height:1254),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:[.interpolation:NSImageInterpolation.high])
                #if CAT_PAW_EXPERIMENT
                if let eyes=cachedGroomEyesImage {
                    NSImage(cgImage:eyes,size:NSSize(width:1254,height:1254)).draw(in:NSRect(x:0,y:0,width:1254,height:1254),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:[.interpolation:NSImageInterpolation.high])
                }
                if let paw=cachedPawImage {
                    // Do not let a hidden paw tint the bed's translucent artwork.
                    ctx.saveGState()
                    let visiblePaw=CGMutablePath()
                    visiblePaw.addRect(CGRect(x:-200,y:-200,width:2000,height:1800))
                    visiblePaw.addPath(frontPath,transform:lean.inverted())
                    ctx.addPath(visiblePaw);ctx.clip(using:.evenOdd)
                    // Keep the antialiased paw edge above the bed's partially transparent rim.
                    let rimGuard=CGMutablePath()
                    rimGuard.addRect(CGRect(x:-200,y:-200,width:2000,height:1800))
                    rimGuard.addPath(frontPath.copy(strokingWithWidth:6,lineCap:.round,lineJoin:.round,miterLimit:2),transform:lean.inverted())
                    ctx.addPath(rimGuard);ctx.clip(using:.evenOdd)
                    if toyFrame.paw>0 {
                        // A small contact shadow separates the original pale paw
                        // from the white chest, without changing either texture.
                        ctx.setShadow(offset:CGSize(width:3,height:5),blur:6,color:NSColor(calibratedWhite:0.2,alpha:0.24).cgColor)
                    }
                    NSImage(cgImage:paw,size:NSSize(width:1254,height:1254)).draw(in:NSRect(x:0,y:0,width:1254,height:1254),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:[.interpolation:NSImageInterpolation.high])
                    ctx.restoreGState()
                }
                #endif
                if let mouth=cachedMouthImage {
                    NSImage(cgImage:mouth,size:NSSize(width:1254,height:1254)).draw(in:NSRect(x:0,y:0,width:1254,height:1254),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:[.interpolation:NSImageInterpolation.high])
                }
            }
        } else {
        ctx.concatenate(catTransform);ctx.addPath(catPath);ctx.clip()
        cat.draw(in:NSRect(x:0,y:0,width:1254,height:1254),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:[.interpolation:NSImageInterpolation.high])
        ctx.saveGState();ctx.clip(to:CGRect(x:590,y:493,width:365,height:120*pose.eyes))
        closed.draw(in:NSRect(x:0,y:0,width:1254,height:1254),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:[.interpolation:NSImageInterpolation.high]);ctx.restoreGState()
        }
        ctx.restoreGState()
        ctx.saveGState();ctx.addPath(frontPath);ctx.clip();drawBed(ctx);ctx.restoreGState();ctx.restoreGState()
        drawToyGuide()
        drawToy(ctx)
        if !text.isEmpty {
            let style=NSMutableParagraphStyle();style.alignment = .center;style.lineBreakMode = .byWordWrapping
            let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:12),.foregroundColor:NSColor(calibratedRed:0.4,green:0.33,blue:0.25,alpha:1),.paragraphStyle:style]
            let str=text as NSString;let size=str.boundingRect(with:NSSize(width:max(80,bounds.width-44),height:100),options:[.usesLineFragmentOrigin],attributes:attrs).size
            let rect=NSRect(x:(bounds.width-size.width-24)/2,y:6,width:size.width+24,height:min(54,size.height+16))
            NSColor(calibratedRed:1,green:0.973,blue:0.914,alpha:1).setFill();NSBezierPath(roundedRect:rect,xRadius:14,yRadius:14).fill()
            str.draw(in:rect.insetBy(dx:12,dy:8),withAttributes:attrs)
            // Receipt still requires a real screen draw. The native region probe
            // distinguishes transparent surfaces from actual opaque coverage.
            if reportedText != text, NSGraphicsContext.current?.isDrawingToScreen == true,
               onTextRendered != nil, needsTextReceipt?(text) ?? true,
               textRectIsUncovered(rect) {
                reportedText = text; onTextRendered?(text)
                DispatchQueue.main.async { [weak self] in self?.updateTextVisibilityProbe() }
            }
        }
    }
    private func updateTextVisibilityProbe() {
        guard !text.isEmpty, reportedText != text, onTextRendered != nil,
              needsTextReceipt?(text) ?? true, let window,
              window.isVisible, !window.isMiniaturized, !NSApp.isHidden else {
            if let probe=textVisibilityProbe {
                probe.parent?.removeChildWindow(probe); probe.orderOut(nil)
                textVisibilityProbe=nil
            }
            return
        }
        let style=NSMutableParagraphStyle();style.alignment = .center;style.lineBreakMode = .byWordWrapping
        let size=(text as NSString).boundingRect(with:NSSize(width:max(80,bounds.width-44),height:100),options:[.usesLineFragmentOrigin],attributes:[.font:NSFont.systemFont(ofSize:12),.paragraphStyle:style]).size
        let rect=NSRect(x:(bounds.width-size.width-24)/2,y:6,width:size.width+24,height:min(54,size.height+16))
        // AppKit aligns window frames to pixels. Outward integral alignment
        // contains the fractional glyph bounds instead of requiring equality.
        let frame=window.convertToScreen(convert(rect,to:nil)).integral
        let probe: NSWindow
        if let existing=textVisibilityProbe { probe=existing }
        else {
            probe=NSWindow(contentRect:frame,styleMask:.borderless,backing:.buffered,defer:false)
            probe.isReleasedWhenClosed=false; probe.backgroundColor = .clear
            probe.isOpaque=false; probe.hasShadow=false; probe.ignoresMouseEvents=true
            probe.isExcludedFromWindowsMenu=true
            probe.collectionBehavior=[.fullScreenNone,.ignoresCycle,.transient]
            probe.setAccessibilityElement(false)
            textVisibilityProbe=probe
        }
        if probe.frame != frame {probe.setFrame(frame,display:false)}
        if probe.level != window.level {probe.level=window.level}
        if probe.parent !== window {probe.parent?.removeChildWindow(probe);window.addChildWindow(probe,ordered:.above)}
        if !probe.isVisible {probe.order(.above,relativeTo:window.windowNumber)}
        // No pixels, input, focus or independent level. This short-lived child
        // asks WindowServer about this region, not other apps' bounding boxes.
        // Existing ticks keep it current only while awaiting a receipt.
    }
    private func textRectIsUncovered(_ rect: NSRect) -> Bool {
        guard let window, window.isVisible, window.alphaValue > 0.99,
              window.occlusionState.contains(.visible), !NSApp.isHidden,
              let probe=textVisibilityProbe, probe.isVisible,
              probe.occlusionState.contains(.visible) else { return false }
        let screenRect = window.convertToScreen(convert(rect, to: nil))
        return probe.frame.contains(screenRect) && NSScreen.screens.contains(where: { $0.visibleFrame.contains(screenRect) })
    }
    func containsCat(_ local:CGPoint)->Bool {
        touchRegion(local) != .none
    }
    var toyCenter:CGPoint {CGPoint(x:toyFrame.position.x*bounds.width,y:60+toyFrame.position.y*bounds.width)}
    private func drawToyGuide() {
        guard let range=toyGuide,toyFrame.opacity>0 else{return}
        let path=NSBezierPath()
        for i in 0...32 {
            let x=range.lowerBound+(range.upperBound-range.lowerBound)*Double(i)/32
            let p=CGPoint(x:x*bounds.width,y:60+(CatToy.groundY(x)+0.022)*bounds.width)
            if i==0 {path.move(to:p)}else{path.line(to:p)}
        }
        let contrast=NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        NSColor(calibratedRed:0.25,green:0.49,blue:0.45,alpha:contrast ? 0.65:0.30).setStroke()
        path.lineWidth=3;path.lineCapStyle = .round;path.stroke()
    }
    func containsToy(_ point:CGPoint)->Bool {
        toyFrame.opacity>0 && hypot(point.x-toyCenter.x,point.y-toyCenter.y)<=max(16,bounds.width*0.05)
    }
    private func drawToy(_ ctx:CGContext) {
        guard toyFrame.opacity>0 else{return}
        let p=toyCenter,r=bounds.width*0.027
        ctx.saveGState();defer{ctx.restoreGState()}
        ctx.setAlpha(toyFrame.opacity)
        NSColor(calibratedWhite:0.2,alpha:0.17).setFill()
        let ground=60+CatToy.groundY(toyFrame.position.x)*bounds.width
        NSBezierPath(ovalIn:NSRect(x:p.x-r*0.92,y:ground+r*0.65,width:r*1.84,height:r*0.6)).fill()
        ctx.translateBy(x:p.x,y:p.y);ctx.rotate(by:toyFrame.rotation)
        let circle=NSBezierPath(ovalIn:NSRect(x:-r,y:-r,width:r*2,height:r*2))
        (growthBallTint ?? NSColor(calibratedRed:0.76,green:0.49,blue:0.38,alpha:1)).setFill();circle.fill()
        circle.addClip()
        NSColor(calibratedRed:0.97,green:0.77,blue:0.58,alpha:0.9).setStroke()
        for offset in [-0.55,0.0,0.55] {
            let strand=NSBezierPath();strand.lineWidth=max(0.7,r*0.11)
            strand.move(to:CGPoint(x:-r*0.9,y:r*offset-r*0.6))
            strand.curve(to:CGPoint(x:r*0.85,y:r*offset+r*0.65),controlPoint1:CGPoint(x:-r*0.9,y:r*offset+r*0.7),controlPoint2:CGPoint(x:r*0.5,y:r*offset-r*0.65));strand.stroke()
        }
        NSColor(calibratedRed:0.38,green:0.25,blue:0.2,alpha:0.28).setStroke();circle.lineWidth=max(0.7,r*0.1);circle.stroke()
    }
    private var catLeanTransform:CGAffineTransform {
        let base=CGAffineTransform(translationX:690,y:800-pose.lean*2.5).rotated(by:-pose.lean*0.32 * .pi/180).translatedBy(x:-690,y:-800)
        return base
    }
    func touchRegion(_ local:CGPoint)->CatTouchRegion {
        guard bounds.width>0,local.x>=0,local.x<=bounds.width,local.y>=60,local.y<=bounds.height else{return .none}
        let p=CGPoint(x:local.x*1525/bounds.width-135,y:(local.y-60)*1525/bounds.width+165)
        let onBed=bedPath.contains(CGPoint(x:p.x+140,y:p.y-250))
        // The foreground rim is drawn over the cat: invisible fur is not touchable.
        if onBed && frontPath.contains(p) {return .bed}
        let lean=catLeanTransform
        let q=useV1Rendering ? p.applying(catTransform.inverted()):CatDeformation.sourcePoint(p.applying(lean.inverted()),pose:pose)
        if catPath.contains(q) {return q.x>=480 ? .head:.back}
        return onBed ? .bed:.none
    }
}
