import Foundation

// Read-only scheduler audit: accelerated time, not a claim of live observation.
@main struct AcceptanceCadence {
    static func main() {
        for grooming in [false, true] {
            var counts:[Int]=[], gaps:[Double]=[], occupied=0, samples=0
            for seed in 1...100 {
                var motion=CatMotion(now:0,seed:UInt64(seed))
                motion.setAutomaticGrooming(grooming,at:0)
                var previous = -Double.infinity, count=0
                for frame in 0..<108000 {
                    let t=Double(frame)/30
                    let pose=motion.frame(t,reduced:false,paused:false)
                    if motion.gestureStart != previous {
                        if previous.isFinite {gaps.append(motion.gestureStart-previous)}
                        previous=motion.gestureStart;count += 1
                    }
                    if pose.mouth.extensionAmount>0 || pose.paw.raise>0 {occupied += 1}
                    samples += 1
                }
                counts.append(count)
            }
            print("autoGrooming=\(grooming) seeds=100 simulatedHours=100 eventsPerHour=\(counts.min()!)...\(counts.max()!) minGap=\(gaps.min()!) mouthOrPawOccupancy=\(100*Double(occupied)/Double(samples))%")
        }
        var motion=CatMotion(now:0,seed:4)
        _=motion.frame(1,reduced:false,paused:false)
        motion.resume(600)
        for t in [600.0,600.29,600.31,601.0] {
            let p=motion.frame(t,reduced:false,paused:false)
            print("longHiddenResume t=\(t) gesture=\(motion.gesture) start=\(motion.gestureStart) tongue=\(p.mouth.extensionAmount)")
        }
    }
}
