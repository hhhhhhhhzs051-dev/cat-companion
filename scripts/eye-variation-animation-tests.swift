import AppKit
import CoreImage

@main struct VariationAnimationTests {
    static func check(_ value:Bool,_ message:String) {
        if !value {fputs("FAIL variation animation: \(message)\n",stderr);exit(1)}
    }
    static func main() throws {
        check(abs(EyeVariation(pupilWidth:1.4).pupilWidth-1.4)<1e-9,
              "requested 40 percent pupil width must not silently clamp to 25 percent")
        check(abs(EyeVariation(pupilWidth:1.125).pupilWidth-1.125)<1e-9,
              "continuous pupil midpoint must not snap back to original between static presets")
        print("PASS continuous pupil parameter between approved endpoints")
        for action in EyeVariationAction.allCases {
            let pupil = action == .pupil || action == .pupilWide
            let peak = action == .pupilWide ? 1.4:1.25
            let midpoint = action == .pupilWide ? 1.2:1.125
            var p=EyeVariationPlayback()
            check(p.sample(at:0) == .neutral && !p.isPlaying,"no autoplay")
            check(p.start(action,at:10),"manual start")
            check(p.sample(at:10) == .neutral,"starts at exact original")
            check(!p.start(.pupil,at:10.1),"busy input cannot interrupt/stack/queue")
            let half=p.sample(at:pupil ? 10.35:10.36)
            if pupil {
                check(abs(half.pupilWidth-midpoint)<1e-8 && half.direction==0,"pupil midpoint without gaze")
            } else {
                check(abs(abs(half.direction)-0.5)<1e-8 && half.pupilWidth==1,"gaze midpoint without pupil change")
            }
            let held=p.sample(at:10.8)
            check(pupil ? held.pupilWidth==peak:abs(held.direction)==1,"requested peak, no overshoot")
            let back=p.sample(at:pupil ? 11.6:11.54)
            check(pupil ? abs(back.pupilWidth-midpoint)<1e-8:abs(abs(back.direction)-0.5)<1e-8,"smooth halfway recovery")
            check(p.sample(at:12.1) == .neutral && !p.isPlaying,"finite endpoint")
            check(p.sample(at:900) == .neutral,"no loop or delayed queued action")
            check(p.start(action,at:20),"explicit replay")
            _=p.sample(at:20.2);p.cancel()
            check(p.sample(at:20.3) == .neutral && !p.isPlaying,"cancel resets")
            check(!p.start(action,at:.infinity),"invalid start fails safe")
            _=p.start(action,at:30)
            check(p.sample(at:.nan) == .neutral && !p.isPlaying,"invalid clock cancels")
        }
        print("PASS playback endpoints, mutual exclusion, repeated input, bounded duration and cancellation")
        _=NSApplication.shared
        let player=EyeVariationPlayer();var states:[EyeVariation]=[]
        player.onChange={s,_ in states.append(s)}
        check(!player.hasActiveTimer,"startup no timer")
        for action in EyeVariationAction.allCases {
            states.removeAll()
            check(player.start(action),"real timer starts")
            check(!player.start(.right),"no second timer")
            RunLoop.main.run(until:Date(timeIntervalSinceNow:2.25))
            check(states.contains{action == .pupilWide ? $0.pupilWidth==1.4:(action == .pupil ? $0.pupilWidth==1.25:abs($0.direction)>0.999)},"timer reaches peak")
            check(player.state == .neutral && !player.isPlaying && !player.hasActiveTimer,"timer stops at original")
            let count=states.count;RunLoop.main.run(until:Date(timeIntervalSinceNow:0.15))
            check(states.count==count,"no idle callbacks")
        }
        _=player.start(.pupil);RunLoop.main.run(until:Date(timeIntervalSinceNow:0.1));player.reducedMotion=true
        check(player.state == .neutral && !player.hasActiveTimer && !player.start(.left),"reduce cancels and blocks")
        player.reducedMotion=false
        check(!player.hasActiveTimer,"reduce off never auto resumes")
        _=player.start(.right);player.cancel()
        check(player.state == .neutral && !player.hasActiveTimer,"lifecycle cancel stops")
        print("PASS real timer: all four one-shots, no idle callbacks, reduce/cancel and no resume")

        let out=URL(fileURLWithPath:CommandLine.arguments[1])
        let view=try NativeCatView(resources:URL(fileURLWithPath:"src"))
        view.frame=NSRect(x:0,y:0,width:290,height:267);view.update(CatPose())
        func bitmap()->NSBitmapImageRep {
            let b=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:580,pixelsHigh:534,bitsPerSample:8,
                samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
            b.size=view.bounds.size;view.cacheDisplay(in:view.bounds,to:b);return b
        }
        func bytes(_ b:NSBitmapImageRep)->Data {Data(bytes:b.bitmapData!,count:b.bytesPerRow*b.pixelsHigh)}
        let original=bytes(bitmap())
        let renderer=EyeVariationRenderer(),frozen=AcceptedStaticEyeVariationRenderer()
        let ci=CIContext(options:[.cacheIntermediates:false])
        let raw=CIImage(contentsOf:URL(fileURLWithPath:"src/assets/cat-d.png"))!
        func rawBitmap(_ image:CIImage)->NSBitmapImageRep {NSBitmapImageRep(cgImage:ci.createCGImage(image,from:raw.extent)!)}
        for (d,w) in [(-1.0,1.0),(0,1),(1,1),(0,1.25)] {
            let b=rawBitmap(renderer.apply(to:raw,state:EyeVariation(direction:d,gain:1.5,pupilWidth:w,fixedAperture:true)))
            let accepted=rawBitmap(frozen.apply(to:raw,state:AcceptedStaticEyeVariation(direction:d,gain:1.5,pupilWidth:w)))
            check(bytes(b)==bytes(accepted),"animated endpoints must exactly match accepted static art")
        }
        var maximum=0,fineMaximum=0,renderTimes:[Double]=[],largest=""
        for action in EyeVariationAction.allCases {
            let pupil = action == .pupil || action == .pupilWide
            let peak = action == .pupilWide ? 1.4:1.25
            var p=EyeVariationPlayback();_=p.start(action,at:0)
            var prior=original
            for frame in 0...122 {
                let state=p.sample(at:Double(frame)/60);view.eyeVariation=state
                let t=ProcessInfo.processInfo.systemUptime,b=bitmap()
                renderTimes.append((ProcessInfo.processInfo.systemUptime-t)*1000)
                let current=bytes(b)
                if frame==48 {check(current != original,"native renderer must visibly apply \(action), not only preserve outside pixels")}
                check(view.pose == CatPose(),"no head/body/ear/eyelid motion")
                check(state.direction==0 || state.pupilWidth==1,"never combine effects")
                for y in 0..<534 {for x in 0..<580 {
                    let pt=CGPoint(x:Double(x)/2,y:Double(y)/2)
                    let inside=CGRect(x:147,y:126,width:22,height:18).contains(pt) || CGRect(x:184,y:126,width:22,height:18).contains(pt)
                    let i=y*b.bytesPerRow+x*4
                    if inside {for c in 0..<3 {
                        let delta=abs(Int(current[i+c])-Int(prior[i+c]))
                        if delta>maximum {maximum=delta;largest="\(action) frame\(frame) pixel\(x),\(y) c\(c)"}
                    }}
                    else {check(current[i..<i+4]==original[i..<i+4],"outside pixels changed \(action) \(frame)")}
                }}
                if state == .neutral {check(current==original,"exact original on return")}
                if [0,20,48,90,122].contains(frame) {try b.representation(using:.png,properties:[:])!.write(to:out.appendingPathComponent("\(action)-\(frame)-290pt.png"))}
                prior=current
            }
            var previous:Data?
            for step in 0...256 {
                let a=Double(step)/256,fixed = !CommandLine.arguments.contains("--moving-aperture")
                view.eyeVariation=pupil ? EyeVariation(pupilWidth:1+(peak-1)*a,fixedAperture:fixed,pupilLimit:peak)
                    :EyeVariation(direction:(action == .left ? -1:1)*a,gain:1.5,fixedAperture:fixed)
                let b=bitmap(),current=bytes(b)
                if let previous {for y in 252..<288 {for x in 294..<412 {
                    let i=y*b.bytesPerRow+x*4
                    for c in 0..<3 {fineMaximum=max(fineMaximum,abs(Int(current[i+c])-Int(previous[i+c]))) }
                }}}
                previous=current
            }
        }
        print("METRIC 492 normal290 frames maximum channel step \(maximum)/255 at \(largest), fine1/256 \(fineMaximum)/255")
        check(fineMaximum<=4,"fine motion cannot toggle an aperture patch")
        check(maximum<=16,"conservative per-frame continuity threshold")
        renderTimes.sort()
        print("METRIC offscreen median \(renderTimes[renderTimes.count/2]) ms, p95 \(renderTimes[Int(Double(renderTimes.count-1)*0.95)]) ms")
        print("PASS accepted static endpoints, every outer pixel/pose fixed, smooth steps and exact recovery")
    }
}
