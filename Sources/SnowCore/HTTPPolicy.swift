import Foundation
public struct HTTPRequest {
    public let method: String
    public let path: String
    public let headers: [String:String]
    public let body: Data
    public init(method: String, path: String, headers: [String:String], body: Data = Data()) { self.method=method; self.path=path; self.headers=headers; self.body=body }
    public static func parse(_ data: Data) -> HTTPRequest? {
        guard data.count <= 49152, let boundary=data.range(of:Data("\r\n\r\n".utf8)), boundary.lowerBound <= 8192,
              let head=String(data:data[..<boundary.lowerBound],encoding:.utf8) else { return nil }
        let lines=head.components(separatedBy:"\r\n"); guard let first=lines.first else { return nil }
        let parts=first.split(separator:" ",omittingEmptySubsequences:false)
        guard parts.count == 3, parts[2] == "HTTP/1.1", parts[1].hasPrefix("/"), !parts[1].contains("#") else { return nil }
        var headers: [String:String]=[:]
        for line in lines.dropFirst() {
            guard let colon=line.firstIndex(of:":"), !line.hasPrefix(" "), !line.hasPrefix("\t") else { return nil }
            let name=String(line[..<colon]).lowercased()
            guard !name.isEmpty, name.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }), headers[name] == nil else { return nil }
            headers[name]=line[line.index(after:colon)...].trimmingCharacters(in:.whitespaces)
        }
        guard headers["transfer-encoding"] == nil else { return nil }
        let size: Int
        if let length=headers["content-length"] { guard !length.isEmpty, length.allSatisfy(\.isNumber), let n=Int(length), n<=32768 else { return nil }; size=n }
        else { size=0 }
        let body=Data(data[boundary.upperBound...]); guard body.count == size else { return nil }
        return HTTPRequest(method:String(parts[0]),path:String(parts[1]),headers:headers,body:body)
    }
}
public struct HTTPPolicy {
    public let port: UInt16
    public let token: String
    public var origin: String { "http://127.0.0.1:\(port)" }
    public init(port: UInt16, token: String) { self.port=port; self.token=token }
    public func authorize(_ r: HTTPRequest) -> Int {
        guard r.headers["host"] == "127.0.0.1:\(port)" else { return 403 }
        if let origin=r.headers["origin"], origin != self.origin { return 403 }
        if let site=r.headers["sec-fetch-site"], !["same-origin","none"].contains(site) { return 403 }
        guard ["GET","POST"].contains(r.method) else { return 405 }
        if r.method == "POST" {
            guard r.headers["origin"] == origin, r.headers["x-snowplay-token"] == token,
                  r.headers["content-type"]?.lowercased() == "application/json" else { return 403 }
        }
        return 200
    }
}
