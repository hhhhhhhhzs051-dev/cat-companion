import AppKit
import ImageIO
import UniformTypeIdentifiers

// Documentation rendering only: no PetApp, windows, saved data or preferences.
@main struct DocumentationDemo {
    static func main() throws {
        _ = NSApplication.shared
        let out = URL(fileURLWithPath: "docs/media", isDirectory: true)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let view = try NativeCatView(resources: URL(fileURLWithPath: "src"))
        view.frame = NSRect(x: 0, y: 0, width: 480, height: 402)
        var motion = CatMotion(now: 0, seed: 42, refinedTouch: true)
        let url = out.appendingPathComponent("head-pet.gif")
        let frames = 54
        guard let gif = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames, nil) else { fatalError("Cannot create GIF") }
        CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for i in 0..<frames {
            autoreleasepool {
                let time = Double(i) / 15
                if i == 12 { motion.pet(time) }
                view.update(motion.frame(time, reduced: false, paused: false))
                let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 480, pixelsHigh: 402, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                view.cacheDisplay(in: view.bounds, to: bitmap)
                if i == 0 || i == 18 {
                    let name = i == 0 ? "rest.png" : "head-pet.png"
                    guard let png = CGImageDestinationCreateWithURL(out.appendingPathComponent(name) as CFURL, UTType.png.identifier as CFString, 1, nil) else { fatalError("Cannot create PNG") }
                    CGImageDestinationAddImage(png, bitmap.cgImage!, nil)
                    guard CGImageDestinationFinalize(png) else { fatalError("Cannot finalize PNG") }
                }
                CGImageDestinationAddImage(gif, bitmap.cgImage!, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 15]] as CFDictionary)
            }
        }
        guard CGImageDestinationFinalize(gif) else { fatalError("Cannot finalize GIF") }
        print("Rendered 54 frames: docs/media/head-pet.gif")
    }
}
