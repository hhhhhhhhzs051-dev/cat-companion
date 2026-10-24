import AppKit
func runMenuTests(_ app:PetApp) {
    // Inspect routes only: never load, migrate or write the user's files.
    func check(_ ok:Bool,_ text:String){if !ok {print("FAIL release storage: \(text)");exit(1)}}
    let directory=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("local.catcompanion.opensource")
    check(!app.selfTest && !app.isPlayPreview,"normal formal startup mode")
    check(app.copyURL==directory.appendingPathComponent("猫咪文案.json"),"original personal copy route, not bundled preview copy")
    check(app.growthStore?.url==directory.appendingPathComponent("成长记录.json"),"original growth route, not app bundle")
    print("PASS normal release routes preserve personal copy and growth without reading/writing either")
}
