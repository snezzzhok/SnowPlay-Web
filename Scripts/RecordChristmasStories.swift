import AppKit
import SpriteKit
import SnowCore
@testable import SnowPlay
@main struct RecordChristmasStories {
 static func main() throws {
  _=NSApplication.shared;NSApp.setActivationPolicy(.accessory);NSApp.finishLaunching()
  let folder=URL(fileURLWithPath:"Docs/Christmas-Stories-Demos");try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
  let theftOnly=CommandLine.arguments.contains("--theft-only")
  var items:[[String:Any]]=[]
  if theftOnly,let data=try? Data(contentsOf:folder.appendingPathComponent("recordings.json")),let old=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] {items=(old["items"] as? [[String:Any]] ?? []).filter{($0["id"] as? String) != "presentTheft"}}
  let cases=theftOnly ? [(ChristmasStoryID.presentTheft,0),(.presentTheft,1)]:ChristmasStoryID.allCases.map{($0,0)}+[(.presentTheft,1)]
  for (id,variant) in cases {
   let fixture=ChristmasStoryFixture(id),file=id.rawValue+"-\(variant).mp4"
   guard fixture.start(id,variant)==nil,let run=fixture.w.decorations.stories.active else {throw NSError(domain:"StoryCapture",code:1)}
   let preview=NSWindow(contentRect:NSRect(x:100,y:100,width:1000,height:650),styleMask:[.titled,.closable],backing:.buffered,defer:false)
   preview.title="SnowPlay — native story preview (closes automatically)";preview.isReleasedWhenClosed=false;preview.backgroundColor=NSColor(calibratedRed:0.07,green:0.15,blue:0.22,alpha:1)
   let host=NSView(frame:fixture.d.canvas.frame);preview.contentView=host;host.addSubview(fixture.view);host.addSubview(fixture.d.desktopCanvas);host.addSubview(fixture.d.canvas);preview.orderBack(nil)
   let ffmpeg=Process(),input=Pipe();ffmpeg.executableURL=URL(fileURLWithPath:"/opt/homebrew/bin/ffmpeg")
   ffmpeg.arguments=["-y","-loglevel","error","-f","rawvideo","-pixel_format","rgba","-video_size","1000x650","-framerate","30","-i","pipe:0","-an","-c:v","libx264","-preset","veryfast","-crf","23","-pix_fmt","yuv420p","-movflags","+faststart",folder.appendingPathComponent(file).path];ffmpeg.standardInput=input;try ffmpeg.run()
   let start=ProcessInfo.processInfo.systemUptime;var frames=0,shot=false
   while !run.finished && frames<6000 {
    fixture.step();fixture.step()
    try autoreleasepool {
     let bitmap=fixture.bitmap(zoomed:true)
     // Labels describe the production scene being rendered; the animation is native SpriteKit.
     NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
     (id.title as NSString).draw(at:NSPoint(x:24,y:605),withAttributes:[.font:NSFont.systemFont(ofSize:20,weight:.semibold),.foregroundColor:NSColor.white])
     ((run.timeline.current?.id ?? "finished").replacingOccurrences(of:"-",with:" ") as NSString).draw(at:NSPoint(x:24,y:582),withAttributes:[.font:NSFont.systemFont(ofSize:12),.foregroundColor:NSColor(calibratedWhite:0.85,alpha:1)])
     NSGraphicsContext.restoreGraphicsState()
     try input.fileHandleForWriting.write(contentsOf:Data(bytes:bitmap.bitmapData!,count:bitmap.bytesPerRow*bitmap.pixelsHigh))
     if run.elapsed>11 && !shot {try bitmap.representation(using:.png,properties:[:])!.write(to:folder.appendingPathComponent(id.rawValue+"-\(variant).png"));shot=true;print("CAPTURE",id.rawValue,run.actors.mapValues{["x":$0.position.x,"y":$0.position.y,"alpha":Double($0.actor.node.alpha),"hidden":$0.actor.node.isHidden ? 1.0:0.0]});fflush(stdout)}
    }
    frames+=1
    // Real elapsed time keeps SpriteKit actions and the actual native renderer in sync.
    let wait=start+Double(frames)/30-ProcessInfo.processInfo.systemUptime
    RunLoop.main.run(until:Date().addingTimeInterval(max(0.001,wait)))
   }
   try input.fileHandleForWriting.close();ffmpeg.waitUntilExit()
   guard ffmpeg.terminationStatus==0,run.succeeded else{throw NSError(domain:"StoryCapture",code:2,userInfo:[NSLocalizedDescriptionKey:run.interruption])}
   items.append(["id":id.rawValue,"title":id.title,"variant":variant,"file":file,"seconds":Double(frames)/30,"scope":"Zoomed native production SpriteKit/AppKit scene in an isolated owned fixture; not a recording of the user's desktop"])
   print("RECORDED",file,"frames",frames,"elapsed",ProcessInfo.processInfo.systemUptime-start);fflush(stdout);preview.orderOut(nil);preview.close();fixture.close()
  }
  items.sort{let ids=ChristmasStoryID.allCases.map(\.rawValue);let a=ids.firstIndex(of:$0["id"] as! String)!,b=ids.firstIndex(of:$1["id"] as! String)!;return a==b ? ($0["variant"] as! Int)<($1["variant"] as! Int):a<b}
  try JSONSerialization.data(withJSONObject:["passed":true,"items":items],options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("recordings.json"))
  var html="<!doctype html><meta charset=utf-8><meta name=viewport content='width=device-width,initial-scale=1'><title>SnowPlay · Christmas Stories</title><style>body{background:#112b3b;color:#eef7fb;font:16px -apple-system,sans-serif;max-width:1050px;margin:40px auto;padding:20px}article{margin:36px 0}video{width:100%;border-radius:15px;background:#142d40}p{color:#b8ccd9;line-height:1.6}</style><h1>Christmas Stories</h1><p>Real native SpriteKit/AppKit scenes using the production engine in an isolated test scene. These videos do not capture other apps or the user’s desktop.</p>"
  for item in items {html+="<article><h2>\(item["title"]!) · \((item["variant"] as! Int)==0 ? "A":"B")</h2><video controls preload=metadata poster='\(item["id"]!)-\(item["variant"]!).png' src='\(item["file"]!)'></video></article>"}
  try html.write(to:folder.appendingPathComponent("index.html"),atomically:true,encoding:.utf8)
  print("PASS: eight native recordings")
 }
}
