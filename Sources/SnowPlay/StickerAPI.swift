import Foundation
import SnowCore
struct StickerPreset:Codable {var version=1;var settings:StickerStudioSettings}
extension WinterCoordinator {
 func stickerRequest(_ request:HTTPRequest)->HTTPResponse {
  guard let body=(try? JSONSerialization.jsonObject(with:request.body)) as? [String:Any],let op=body["op"] as? String else{return .json(["error":"Invalid decoration command"],status:400)}
  if op=="import-begin" {
   guard let object=body["preset"],let data=try? JSONSerialization.data(withJSONObject:object),var preset=try? JSONDecoder().decode(StickerPreset.self,from:data),preset.version==1,preset.settings.items.isEmpty else{return .json(["error":"Invalid composition header"],status:400)}
   preset.settings.validate();stickerStudio.pendingImport=preset.settings;stickerStudio.importStarted=ProcessInfo.processInfo.systemUptime;return .json(["ok":true])
  }
  if op=="import-part" {
   guard var pending=stickerStudio.pendingImport,ProcessInfo.processInfo.systemUptime-stickerStudio.importStarted<60,let object=body["items"],let data=try? JSONSerialization.data(withJSONObject:object),let items=try? JSONDecoder().decode([StudioSticker].self,from:data),items.count<=32,pending.items.count+items.count<=720 else{return .json(["error":"Invalid or expired composition upload"],status:400)}
   pending.items+=items;stickerStudio.pendingImport=pending;return .json(["ok":true])
  }
  if op=="import-end" {
   guard var pending=stickerStudio.pendingImport,ProcessInfo.processInfo.systemUptime-stickerStudio.importStarted<60 else{return .json(["error":"Composition upload expired"],status:400)}
   pending.validate();let before=config.stickers;config.stickers=pending;stickerStudio.pendingImport=nil;stickerStudio.commit(before);return .json(stateJSON())
  }
  if op=="import" {
   guard let preset=body["preset"],let data=try? JSONSerialization.data(withJSONObject:preset),var decoded=try? JSONDecoder().decode(StickerPreset.self,from:data),decoded.version==1 else{return .json(["error":"Unsupported or invalid preset"],status:400)}
   decoded.settings.validate();let before=config.stickers;config.stickers=decoded.settings;stickerStudio.commit(before);return .json(stateJSON())
  }
  guard stickerStudio.apply(op,body) else{return .json(["error":stickerStudio.status.isEmpty ? "Select an unlocked decoration":stickerStudio.status],status:409)}
  return .json(stateJSON())
 }
}
