import AppKit

// Real PetApp.moveToy + NativeCatView rendering, no settings or duplicate app.
func runMenuTests(_ app:PetApp) {
 app.art=try! NativeCatView(resources:URL(fileURLWithPath:"src"))
 app.art.frame=NSRect(x:0,y:0,width:290,height:267)
 app.paused=false;app.active=true;app.petVisible=true
 app.motion=CatMotion(now:app.now,seed:7)
 app.toy.start(app.now);app.toy.grab(app.now)
 if CommandLine.arguments.contains("--check-input") {
  app.tick()
  let pose=app.art.pose
  app.moveToy(CGPoint(x:180,y:166))
  guard app.art.pose==pose,abs(app.art.toyCenter.x-180)<0.01 else {
   fputs("FAIL drag must update the ball immediately without advancing the cat pose\n",stderr);exit(1)
  }
  print("PASS pointer fast path keeps cat pose on animation clock and ball on input clock")
  return
 }
 var samples:[Double]=[]
 let cpu=clock(),start=ProcessInfo.processInfo.systemUptime
 for i in 0..<360 {
  autoreleasepool {
   // Deliver 120Hz pointer input and the unchanged 30Hz cat clock.
   let deadline=start+Double(i)/120
   let delay=deadline-ProcessInfo.processInfo.systemUptime
   if delay>0 {Thread.sleep(forTimeInterval:delay)}
   let t=ProcessInfo.processInfo.systemUptime
   if i%4==0 {app.tick()}
   app.moveToy(CGPoint(x:290*(0.61+sin(Double(i)/35)*0.12),y:60+290*0.36))
   let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:580,pixelsHigh:534,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
   rep.size=app.art.bounds.size;app.art.cacheDisplay(in:app.art.bounds,to:rep)
   samples.append((ProcessInfo.processInfo.systemUptime-t)*1000)
  }
 }
 let s=samples.sorted()
 print("INPUT 360 events CPU=\(Double(clock()-cpu)/Double(CLOCKS_PER_SEC)) wall=\(ProcessInfo.processInfo.systemUptime-start) p50_ms=\(s[180]) p95_ms=\(s[342]) max_ms=\(s.last!) over8ms=\(s.filter{$0>8.333}.count)")
}
