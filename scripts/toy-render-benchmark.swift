import AppKit
import CryptoKit
@main struct ToyRenderBenchmark {
 static func main() throws {
  let view=try NativeCatView(resources:URL(fileURLWithPath:"src"))
  view.frame=NSRect(x:0,y:0,width:290,height:267)
  var times:[Double]=[],hash=SHA256()
  let cpu=clock(),start=ProcessInfo.processInfo.systemUptime
  for i in 0..<360 {
   autoreleasepool {
    // Identical 120Hz input stream; cat pose runs at 30Hz. No CatToy timing dependency.
    let tick=Double(i/4)/30,look=sin(tick*3)*0.8
    let pose=CatPose(breath:(1-cos(tick))/2,leftEar:0.5+look*0.3,rightEar:0.5-look*0.3,lookX:look)
    let frame=CatToyFrame(position:CGPoint(x:0.61+sin(Double(i)/35)*0.12,y:0.36),opacity:1)
    let t=ProcessInfo.processInfo.systemUptime
    view.update(pose);view.toyFrame=frame
    let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:580,pixelsHigh:534,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    rep.size=view.bounds.size;view.cacheDisplay(in:view.bounds,to:rep)
    times.append((ProcessInfo.processInfo.systemUptime-t)*1000)
    hash.update(data:Data(bytes:rep.bitmapData!,count:rep.bytesPerRow*rep.pixelsHigh))
   }
  }
  let sorted=times.sorted()
  print("BENCH 360 drag frames wall_s=\(ProcessInfo.processInfo.systemUptime-start) cpu_s=\(Double(clock()-cpu)/Double(CLOCKS_PER_SEC)) p50_ms=\(sorted[180]) p95_ms=\(sorted[342]) max_ms=\(sorted.last!) over16ms=\(times.filter{$0>16.67}.count) RGBA=\(hash.finalize())")
 }
}
