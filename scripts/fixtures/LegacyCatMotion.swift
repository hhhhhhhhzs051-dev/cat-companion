import Foundation

// Frozen build 36 motion for preservation comparisons; shares the unchanged pose types.
struct LegacyCatMotion {
    private var seed:UInt64
    private(set) var mood=CatMood.quiet
    private(set) var gesture=CatGesture.leftEar
    private(set) var gestureStart = -Double.infinity
    private(set) var gestureAmplitude=1.0
    var nextGesture=Double.infinity
    var petStart = -Double.infinity, petEnd = -Double.infinity
    var nextBlink=Double.infinity
    private var eyeStart = -Double.infinity, initialEyes=0.0
    private var leanEnd = -Double.infinity, initialLean=0.0
    private var lastPose=CatPose()
    private var settlingUntil = -Double.infinity
    private var breathStart=0.0, breathPeriod=3.6, breathAmplitude=0.8
    private var nextMouthAllowed=Double.infinity
    private var demoStart = -Double.infinity
    private var contactRegion=CatTouchRegion.none
    private var contactStart = -Double.infinity, contactUntil = -Double.infinity
    private var contactFrom=CatPose()
    private var backResponse=false
    private var backEyesCancelled=false
    private func contactPose(_ now:Double)->CatPose {
        guard contactRegion != .none else{return CatPose()}
        let blend=Self.smooth((now-contactStart)/0.18),tail=1-Self.smooth((now-contactUntil)/0.8)
        func value(_ previous:Double,_ target:Double)->Double {(previous+(target-previous)*blend)*tail}
        return CatPose(eyes:value(contactFrom.eyes,contactRegion == .back ? 0:0.55),
                       leftEar:value(contactFrom.leftEar,contactRegion == .back ? 0.85:0.25),
                       head:value(contactFrom.head,contactRegion == .back ? -0.55:0.35))
    }
    #if CAT_PAW_EXPERIMENT
    private(set) var automaticGrooming=false
    private var nextGroomAllowed=Double.infinity
    private var groomExitStart = -Double.infinity
    private var groomExitPose:CatPose?
    private func groomingActive(_ now:Double)->Bool {gesture == .pawLick && now>=gestureStart && now<gestureStart+3.9 || now<groomExitStart+0.5}
    mutating func setAutomaticGrooming(_ enabled:Bool,at now:Double) {
        guard enabled != automaticGrooming else{return}
        automaticGrooming=enabled
        nextGroomAllowed=enabled ? now+random(45,70):.infinity
    }
    #endif
    mutating func resume(_ now:Double) {
        let mouthDue=nextMouthAllowed,gestureDue=nextGesture
        #if CAT_PAW_EXPERIMENT
        let groomDue=nextGroomAllowed
        #endif
        reset(now)
        if mouthDue.isFinite {nextMouthAllowed=max(now+0.3,mouthDue)}
        if gestureDue.isFinite {nextGesture=max(now+0.3,gestureDue)}
        #if CAT_PAW_EXPERIMENT
        if groomDue.isFinite {nextGroomAllowed=max(now+24,groomDue)}
        #endif
    }
    mutating func startDemo(_ now:Double) {
        #if CAT_PAW_EXPERIMENT
        guard !groomingActive(now) else{return}
        #endif
        demoStart=now;gestureStart = -.infinity
        nextGesture=now+15;nextBlink=now+13;nextMouthAllowed=now+12+random(35,55)
    }
    private func demoState(_ now:Double)->(kind:CatGesture,start:Double)? {
        let age=now-demoStart
        guard age>=0,age<12 else{return nil}
        let index=Int(age/3)
        return (index%2==0 ? .tongueTip:.noseLick,demoStart+Double(index)*3)
    }
    func demoLabel(_ now:Double)->String? {
        guard let state=demoState(now) else{return nil}
        return state.kind == .tongueTip ? "动作演示 · 露舌尖":"动作演示 · 舔鼻"
    }

    init(now:Double=ProcessInfo.processInfo.systemUptime, seed:UInt64=UInt64.random(in:1...UInt64.max)) {
        self.seed=seed;reset(now)
    }
    private mutating func random(_ low:Double,_ high:Double)->Double {
        seed=seed &* 6364136223846793005 &+ 1442695040888963407
        return low+(high-low)*Double(seed >> 11)/9007199254740992
    }
    static func smooth(_ value:Double)->Double {let x=max(0,min(1,value));return x*x*(3-2*x)}
    // A held pose with a quick, soft arrival and slower release, never a rubbery oscillation.
    static func envelope(_ t:Double,rise:Double,hold:Double,fall:Double)->Double {
        if t<0 || t>=rise+hold+fall {return 0}
        if t<rise {return smooth(t/rise)}
        if t<rise+hold {return 1}
        return 1-smooth((t-rise-hold)/fall)
    }
    mutating func reset(_ now:Double) {
        #if CAT_PAW_EXPERIMENT
        groomExitPose=nil;groomExitStart = -.infinity
        nextGroomAllowed=automaticGrooming ? now+random(45,70):.infinity
        #endif
        petStart = -.infinity;petEnd = -.infinity;eyeStart = -.infinity
        gestureStart = -.infinity;settlingUntil = -.infinity
        demoStart = -.infinity
        contactRegion = .none;contactStart = -.infinity;contactUntil = -.infinity;contactFrom=CatPose();backResponse=false;backEyesCancelled=false
        leanEnd = -.infinity;initialLean=0
        mood = .quiet;lastPose=CatPose();initialEyes=0
        nextBlink=now+random(3,7);nextGesture=now+random(20,28)
        nextMouthAllowed=now+random(8,14)
        breathStart=now;breathPeriod=random(3.2,3.9);breathAmplitude=random(0.75,1)
    }
    mutating func pet(_ now:Double) {
        endStroke(now);backResponse=false;backEyesCancelled=false
        #if CAT_PAW_EXPERIMENT
        if gesture == .pawLick && now<gestureStart+3.9 {
            groomExitPose=lastPose;groomExitStart=now;gestureStart = -.infinity
        }
        #endif
        if let current=demoState(now) {gesture=current.kind;gestureStart=current.start}
        demoStart = -.infinity
        if now>=petEnd {petStart=now}
        initialEyes=lastPose.eyes;initialLean=lastPose.lean;eyeStart=now;petEnd=now+1.9;leanEnd=petEnd
        nextBlink=petEnd+random(3,7);settlingUntil=petEnd+random(12,22)
        nextGesture=max(nextGesture,settlingUntil+random(4,10));mood = .settling
    }
    mutating func touchBack(_ now:Double) {
        let continuing=contactPose(now)
        pet(now) // Same priority and gentle paw retraction, without a head-click blink.
        backResponse=true
        contactRegion = .back;contactStart=now;contactUntil=now+0.35;contactFrom=continuing
    }
    mutating func stroke(_ region:CatTouchRegion,at now:Double) {
        guard region == .head || region == .back else{return}
        contactFrom=contactPose(now)
        contactStart=now;contactRegion=region;contactUntil=now+0.18
        petEnd=max(petEnd,now+1.2);settlingUntil=max(settlingUntil,now+12)
        nextGesture=max(nextGesture,settlingUntil+4);nextBlink=max(nextBlink,now+3)
    }
    mutating func endStroke(_ now:Double) {
        // Keep a short tail so release does not snap or start a second click.
        contactUntil=min(contactUntil,now+0.08)
    }
    mutating func begin(_ kind:CatGesture,at now:Double,amplitude:Double=1) {
        #if CAT_PAW_EXPERIMENT
        guard !groomingActive(now) else{return}
        if kind == .pawLick {
            guard now>=petEnd else{return}
            demoStart = -.infinity;nextBlink=now+4+random(3,7)
            nextGroomAllowed=now+random(90,150)
            nextMouthAllowed=now+random(35,55)
        }
        #endif
        gesture=kind;gestureStart=now;gestureAmplitude=max(0,min(1,amplitude))
        nextGesture=now+random(24,52)
        if kind == .slowBlink {nextBlink=now+random(5,9)}
        if kind == .tongueTip || kind == .noseLick {nextMouthAllowed=now+random(35,55)}
    }
    func canPlayWithToy(_ now:Double)->Bool {
        now>=petEnd && canTakeOutToy(now)
    }
    func canTakeOutToy(_ now:Double)->Bool {
        #if CAT_PAW_EXPERIMENT
        if groomingActive(now) {return false}
        #endif
        return demoState(now)==nil && lastPose.mouth.extensionAmount==0
    }
    mutating func frame(_ now:Double,reduced:Bool,paused:Bool,engaged:Bool=false)->CatPose {
        // Manual play reserves quiet time; existing cooldowns can only move later.
        // Finishing play never flushes a backlog of automatic gestures.
        if engaged {
            nextGesture=max(nextGesture,now+12)
            nextMouthAllowed=max(nextMouthAllowed,now+18)
        }
        #if CAT_PAW_EXPERIMENT
        if paused || reduced {
            if gesture == .pawLick {gestureStart = -.infinity}
            groomExitPose=nil;groomExitStart = -.infinity
        }
        #endif
        if (paused || reduced) && backResponse {backEyesCancelled=true}
        if paused {demoStart = -.infinity;contactRegion = .none;lastPose=CatPose();return lastPose}
        if reduced {demoStart = -.infinity;contactRegion = .none}
        var pose=CatPose()
        if !reduced {
            if now>=breathStart+breathPeriod {
                breathStart=now;breathPeriod=random(3.2,3.9);breathAmplitude=random(0.75,1)
            }
            let phase=max(0,(now-breathStart)/breathPeriod)
            pose.breath=breathAmplitude*(phase<0.38 ? Self.smooth(phase/0.38):1-Self.smooth((phase-0.38)/0.62))
            let mouthDue=now>=nextMouthAllowed && now>=gestureStart+24
            // Reserve a quiet gap before a due mouth action instead of stacking
            // an ear/head action immediately before it or delaying the mouth again.
            let otherDue=now>=nextGesture && nextMouthAllowed>=now+24
            if !engaged && (otherDue || mouthDue) && now>=petEnd && now>=settlingUntil {
                // Quiet gestures dominate; no immediate repeat. A late frame starts only one event.
                var choices:[CatGesture]=[.leftEar,.rightEar,.slowBlink,.slowBlink,.headDown,.headUp,.listenLeft,.listenRight]
                if mouthDue {choices = [.tongueTip,.noseLick]}
                #if CAT_PAW_EXPERIMENT
                if mouthDue && automaticGrooming && now>=nextGroomAllowed {choices = [.pawLick]}
                #endif
                let eligible=choices.count==1 ? choices:choices.filter{$0 != gesture}
                let choice=eligible[min(eligible.count-1,Int(random(0,Double(eligible.count))))]
                let amplitude=random(0.65,1);begin(choice,at:now,amplitude:amplitude)
            }
            let age=now-gestureStart
            let ear=gestureAmplitude*Self.envelope(age,rise:0.22,hold:0.20,fall:0.82)
            let listen=gestureAmplitude*Self.envelope(age,rise:0.28,hold:0.70,fall:1.05)
            let head=gestureAmplitude*Self.envelope(age,rise:1.05,hold:0.55,fall:1.65)
            switch gesture {
            case .leftEar:pose.leftEar=ear
            case .rightEar:pose.rightEar=ear
            case .listenLeft:
                pose.leftEar=listen
                pose.rightEar=0.18*gestureAmplitude*Self.envelope(age-0.18,rise:0.30,hold:0.42,fall:1.02)
            case .listenRight:
                pose.rightEar=listen
                pose.leftEar=0.15*gestureAmplitude*Self.envelope(age-0.22,rise:0.30,hold:0.38,fall:1.02)
            case .headDown:pose.head=head
            case .headUp:pose.head = -head
            case .slowBlink:
                // Half-narrow, briefly close, then reopen gently. Separate from the 700ms pet response.
                pose.eyes=0.55*Self.envelope(age,rise:0.32,hold:0.48,fall:0.58)
                    + 0.45*Self.envelope(age-0.42,rise:0.24,hold:0.14,fall:0.42)
            case .tongueTip:pose.mouth=CatMouth.pose(.tongueTip,elapsed:age)
            case .noseLick:pose.mouth=CatMouth.pose(.noseLick,elapsed:age)
            #if CAT_PAW_EXPERIMENT
            case .pawLick:
                let grooming=CatGrooming.pose(elapsed:age)
                if age>=0 && age<3.9 {pose=grooming.cat;pose.paw=grooming.paw}
            #endif
            }
            mood=now<settlingUntil ? .settling : ((gesture == .listenLeft || gesture == .listenRight) && age<2.5 ? .attentive : .quiet)
            if let demo=demoState(now) {
                pose.leftEar=0;pose.rightEar=0;pose.head=0
                pose.mouth=CatMouth.pose(demo.kind == .tongueTip ? .tongueTip:.noseLick,elapsed:now-demo.start)
            }
        }
        #if CAT_PAW_EXPERIMENT
        if !reduced,let exiting=groomExitPose {
            let t=now-groomExitStart,weight=1-Self.smooth(t/0.5)
            if weight>0 {
                pose.head=exiting.head*weight;pose.groomingProfile=true
                pose.paw=PawPose(raise:exiting.paw.raise*weight,offsetX:exiting.paw.offsetX*weight)
                pose.mouth=exiting.mouth;pose.mouth.extensionAmount *= 1-Self.smooth(t/0.12)
            }else{groomExitPose=nil}
        }
        #endif
        if now<petEnd {
            let remaining=eyeStart+0.7-now
            if backResponse {
                // One soft closure per body contact. Drag events extend the ear/head
                // response, never this clock; don't hold a blink's in-between artwork.
                let age=now-eyeStart
                pose.eyes=(reduced || backEyesCancelled) ? 0:(initialEyes+(1-initialEyes)*Self.smooth(age/0.14))*(1-Self.smooth((age-0.22)/0.34))
            } else {
                pose.eyes=reduced ? (remaining>0 ? 1:0) : (initialEyes+(1-initialEyes)*Self.smooth((now-eyeStart)/0.065))*Self.smooth(remaining/0.110)
            }
            pose.lean=reduced ? 0:(backResponse ? initialLean*(1-Self.smooth((now-eyeStart)/0.35)):(initialLean+(1-initialLean)*Self.smooth((now-eyeStart)/0.160))*Self.smooth((leanEnd-now)/0.420))
        } else if !reduced && pose.eyes==0 && now>=nextBlink {
            let elapsed=now-nextBlink
            if elapsed<0.055 {pose.eyes=Self.smooth(elapsed/0.055)}
            else if elapsed<0.080 {pose.eyes=1}
            else if elapsed<0.190 {pose.eyes=1-Self.smooth((elapsed-0.080)/0.110)}
            else {nextBlink=now+random(3,7)}
        }
        if !reduced && contactRegion != .none {
            let contact=contactPose(now)
            pose.leftEar=max(pose.leftEar,contact.leftEar)
            pose.head=max(-1,min(1,pose.head+contact.head))
            pose.eyes=max(pose.eyes,contact.eyes)
            if contact.leftEar>0 {mood = .settling}
        }
        lastPose=pose;return pose
    }
}

