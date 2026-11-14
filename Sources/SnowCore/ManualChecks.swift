import Foundation
public struct ManualCheckResult: Codable {
    public var status: String
    public var note: String
    public init(status: String, note: String) { self.status=status; self.note=note }
}
public struct ManualCheckProgress: Codable {
    public var current=0
    public var results: [String:ManualCheckResult]=[:]
    public init() {}
    public mutating func validate() {
        current=min(18,max(0,current))
        results=results.filter { entry in
            guard let index=Int(entry.key), index>=1,index<=19, String(index)==entry.key else { return false }
            return ["passed","failed","skipped","pending"].contains(entry.value.status)
        }
        for key in Array(results.keys) { if var record=results[key] { record.note=String(record.note.prefix(1000)); results[key]=record } }
    }
    public static func load(from url: URL) -> ManualCheckProgress {
        guard let data=try? Data(contentsOf:url), var progress=try? JSONDecoder().decode(Self.self,from:data) else { return Self() }
        progress.validate(); return progress
    }
    public func save(to url: URL) throws {
        try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
        try JSONEncoder().encode(self).write(to:url,options:.atomic)
    }
}
