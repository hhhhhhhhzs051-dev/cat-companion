import Foundation

@main struct CompanionProgressTests {
    static func main() {
        func check(_ value: Bool, _ message: String) {
            if !value { fputs("FAIL: \(message)\n", stderr); exit(1) }
        }
        // Literal XP boundaries from the accepted curve, not computed by the
        // presenter under test. New presentation must not cap growth at 10/30.
        let fixtures: [(Int, Int, Int, Int?, Int?)] = [
            (-1,0,0,nil,30), (0,0,0,nil,30), (5,2,0,nil,30), (6,3,1,nil,30),
            (18,6,1,nil,30), (19,7,2,nil,30), (32,10,2,nil,30),
            (194,29,2,nil,30), (195,30,2,30,40), (284,37,2,30,40),
            (326,39,2,30,40), (327,40,2,40,50), (492,50,2,50,60),
            (1817,100,2,100,110), (2182,110,2,110,120),
            (2_000_000,3459,2,3450,nil), (Int.max,3459,2,3450,nil)
        ]
        for (points, level, familiar, last, next) in fixtures {
            let p = CatCompanionProgress(points: points)
            check(p.level == level, "keep accepted XP curve at \(points)")
            check(p.familiarity.count == familiar, "never show unearned familiarity or invent later speech at \(level)")
            check(p.latestMilestone == last && p.nextMilestone == next, "bounded milestone arithmetic at \(level)")
            check(!p.milestoneText.contains("解锁") && !p.milestoneText.contains("领取"), "memories cannot promise a new reward")
            check(!p.milestoneText.contains("老朋友"), "rejected wording stays absent from the milestone")
        }
        check(CatCompanionProgress(points:492).milestoneText != CatCompanionProgress(points:1817).milestoneText,
              "50 and 100 have distinct earned commemorations")
        check(CatPetLines.candidates(base: [], level: 3).count == 2 &&
              CatPetLines.candidates(base: [], level: 7).count == 4 &&
              CatPetLines.candidates(base: [], level: 100).count == 4,
              "displayed familiarity matches existing speech, without new high-level speech or frequency")
        print("PASS long-term presentation: accepted curve, unearned/earned familiarity, 29/30 and 39/40 boundaries, 50/100 memories and safe high-level fallback")
    }
}
