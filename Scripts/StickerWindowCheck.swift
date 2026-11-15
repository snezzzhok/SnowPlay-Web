import AppKit
import SnowCore
@testable import SnowPlay
@main struct StickerWindowCheck {static func main() throws {
 _=NSApplication.shared
 let child=Process(),input=Pipe(),output=Pipe();child.executableURL=URL(fileURLWithPath:".build/window-fixture");child.arguments=["--controlled"];child.standardInput=input;child.standardOutput=output;try child.run();defer{try? input.fileHandleForWriting.write(contentsOf:Data("quit\n".utf8));if child.isRunning{child.terminate()}}
 let f=ChristmasStoryFixture(.presentTheft),w=f.w,studio=w.stickerStudio;defer{f.close()}
 func poll(){w.observer.poll(now:ProcessInfo.processInfo.systemUptime,screens:[f.d.rect],trackAccessibility:false)}
 func wait(_ test:()->Bool){for _ in 0..<35 {poll();if test(){return};RunLoop.main.run(until:Date().addingTimeInterval(0.1))};preconditionFailure("Actual owned WindowServer fixture did not reach requested state")}
 wait{w.observer.sorted.contains{$0.pid==child.processIdentifier && $0.isVisible}}
 w.interactionWindowSource={w.observer.sorted.filter{$0.pid==child.processIdentifier}}
 let window=w.interactionWindows.first!,point=Vec(window.frame.maxX-20,window.frame.y+12)
 let sticker=studio.attachment("sticker_wreath",at:point,display:f.d);precondition(sticker.anchor.kind == .window);w.config.stickers.items=[sticker];let first=studio.resolve(sticker)!.point
 try input.fileHandleForWriting.write(contentsOf:Data("move\n".utf8));wait{studio.resolve(sticker)?.point != first};let moved=studio.resolve(sticker)!.point;precondition(moved==StickerGeometry.windowPoint(sticker.anchor.local,frame:window.frame))
 let width=window.frame.width;try input.fileHandleForWriting.write(contentsOf:Data("resize\n".utf8));wait{window.frame.width != width};precondition(studio.resolve(sticker)!.point==StickerGeometry.windowPoint(sticker.anchor.local,frame:window.frame))
 try input.fileHandleForWriting.write(contentsOf:Data("minimize\n".utf8));wait{!window.isVisible};precondition(studio.resolve(sticker)==nil)
 try input.fileHandleForWriting.write(contentsOf:Data("restore\n".utf8));wait{window.isVisible};precondition(studio.resolve(sticker) != nil)
 try input.fileHandleForWriting.write(contentsOf:Data("close\n".utf8));wait{!window.isVisible};precondition(studio.resolve(sticker)==nil)
 try JSONSerialization.data(withJSONObject:["passed":true,"scope":"Actual WindowServer geometry from a separate disposable AppKit window through production WindowObserver; no private API","move":true,"resize":true,"minimizeRestore":true,"close":true],options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Docs/sticker-studio-window-result.json"));print("PASS: actual window move, resize, minimize, restore and close")
}}
