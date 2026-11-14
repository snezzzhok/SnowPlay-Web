import Foundation
public struct AssetManifest: Decodable {
    public struct Asset: Decodable {
        public let id: String
        public let category: String
        public let svg: String
        public let preview: String
        public let anchor: Vec
    }
    public let assets: [Asset]
    public func validatedRegistry(at root: URL) throws -> [String:Asset] {
        var registry: [String:Asset]=[:]
        for asset in assets {
            guard registry[asset.id] == nil, asset.anchor.x.isFinite, asset.anchor.y.isFinite else { throw AssetError.invalid(asset.id) }
            for path in [asset.svg,asset.preview] {
                guard Self.safeRelativePath(path), FileManager.default.fileExists(atPath:root.appendingPathComponent(path).path) else { throw AssetError.invalid(path) }
            }
            registry[asset.id]=asset
        }
        return registry
    }
    public static func safeRelativePath(_ path: String) -> Bool {
        !path.isEmpty && !path.hasPrefix("/") && !path.contains("\\") && !path.split(separator:"/",omittingEmptySubsequences:false).contains(where: { $0 == ".." || $0 == "." || $0.isEmpty })
    }
    public enum AssetError: Error { case invalid(String) }
}
