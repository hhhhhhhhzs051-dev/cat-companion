import AppKit

@main struct ToyRestRenderTests {
 static func main() throws {
  let old=try Build48NativeCatView(resources:URL(fileURLWithPath:"src"))
  let new=try NativeCatView(resources:URL(fileURLWithPath:"src"))
  for v in [old as NSView,new as NSView] {v.frame=NSRect(x:0,y:0,width:290,height:60+290*1085/1525)}
  func capture(_ v:NSView)->Data {
   let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:580,pixelsHigh:534,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
   rep.size=v.bounds.size;v.cacheDisplay(in:v.bounds,to:rep)
   return Data(bytes:rep.bitmapData!,count:rep.bytesPerRow*rep.pixelsHigh)
  }
  var ball=CatToyFrame();ball.opacity=1;ball.position=CGPoint(x:0.61,y:CatToy.groundY(0.61))
  old.toyFrame=ball;new.toyFrame=ball
  let mode=CommandLine.arguments.dropFirst().first ?? "check"
  if mode=="check" {
   for width in [200.0,290,440] {
    for v in [old as NSView,new as NSView] {v.frame=NSRect(x:0,y:0,width:width,height:60+width*1085/1525)}
    for i in 0...48 {
     autoreleasepool {
      let p=CatPose(breath:Double(i)/48);old.update(p);new.update(p)
      precondition(capture(old)==capture(new),"Resting ball and cat pixels must match build 48")
     }
    }
   }
   precondition(new.idleCacheCount>0 && new.idleCacheBytes<=64*1024*1024,"Resting ball must use the bounded cache")
   new.update(CatPose(breath:0.25));_=capture(new);let first=new.renderedCatImage!
   new.update(CatPose(breath:0.75));_=capture(new);new.update(CatPose(breath:0.25));_=capture(new)
   precondition(new.renderedCatImage === first,"Retained ball cannot defeat A-B-A breathing reuse")
   if let path=ProcessInfo.processInfo.environment["CAT_PLAY_GUIDE_SNAPSHOT"] {
    new.frame=NSRect(x:0,y:0,width:290,height:60+290*1085/1525)
    new.toyGuide=CatToyReach.guideSpan(for:.pull)
    let rep=new.bitmapImageRepForCachingDisplay(in:new.bounds)!
    new.cacheDisplay(in:new.bounds,to:rep)
    try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:path))
   }
   print("PASS parked-ball exact build48 pixels at 200/290/440pt; bounded A-B-A bitmap reuse")
   return
  }
  precondition(["baseline-idle","baseline-ball","preview-ball"].contains(mode))
  if mode=="baseline-idle" {old.toyFrame=CatToyFrame()}
  // Warm the existing 49-frame cache; benchmark steady state, not first launch.
  for i in 0...48 {autoreleasepool {
   let p=CatPose(breath:Double(i)/48);old.update(p);new.update(p)
   _=capture(mode=="preview-ball" ? new:old)
  }}
  let cpu=clock(),start=ProcessInfo.processInfo.systemUptime
  var checksum:UInt64=0
  for i in 0..<900 {autoreleasepool {
   let p=CatPose(breath:(1-cos(Double(i)/30/3.5 * .pi*2))/2)
   old.update(p);new.update(p)
   let data=capture(mode=="preview-ball" ? new:old)
   for offset in stride(from:0,to:data.count,by:997) {checksum &+= UInt64(data[offset])}
  }}
  print("BENCH \(mode) frames=900 cpu_s=\(Double(clock()-cpu)/Double(CLOCKS_PER_SEC)) wall_s=\(ProcessInfo.processInfo.systemUptime-start) checksum=\(checksum) cache_bytes=\(new.idleCacheBytes)")
 }
}
