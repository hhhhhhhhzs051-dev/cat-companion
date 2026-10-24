import AppKit
let path=CommandLine.arguments[1]
let icon=NSWorkspace.shared.icon(forFile:path)
icon.size=NSSize(width:256,height:256)
let data=icon.tiffRepresentation!
let bitmap=NSBitmapImageRep(data:data)!
try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[2]))
print("Resolved icon:",icon.representations.map {"\($0.pixelsWide)x\($0.pixelsHigh)"})
