import Foundation
import Darwin
import SnowCore
import Security

struct HTTPResponse {
    var status: Int = 200
    var type = "application/json; charset=utf-8"
    var body: Data
    static func json(_ object: Any, status: Int = 200) -> HTTPResponse { HTTPResponse(status:status,body:(try? JSONSerialization.data(withJSONObject:object,options:.sortedKeys)) ?? Data("{}".utf8)) }
}
final class LocalServer {
    private var listener: Int32 = -1
    private let queue=DispatchQueue(label:"snowplay.http",qos:.utility)
    private(set) var policy=HTTPPolicy(port:0,token:"")
    var handler: ((HTTPRequest)->HTTPResponse)?
    var url: URL { URL(string:policy.origin)! }
    func start() throws {
        listener=socket(AF_INET,SOCK_STREAM,0)
        guard listener >= 0 else { throw NSError(domain:NSPOSIXErrorDomain,code:Int(errno)) }
        var reuse: Int32=1; setsockopt(listener,SOL_SOCKET,SO_REUSEADDR,&reuse,socklen_t(MemoryLayout.size(ofValue:reuse)))
        var address=sockaddr_in(); address.sin_family=sa_family_t(AF_INET); address.sin_len=UInt8(MemoryLayout<sockaddr_in>.size); address.sin_port=0; address.sin_addr=in_addr(s_addr:inet_addr("127.0.0.1"))
        let bound=withUnsafePointer(to:&address) { p in p.withMemoryRebound(to:sockaddr.self,capacity:1) { Darwin.bind(listener,$0,socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        guard bound == 0, listen(listener,8)==0 else { let code=errno; stop(); throw NSError(domain:NSPOSIXErrorDomain,code:Int(code)) }
        var length=socklen_t(MemoryLayout<sockaddr_in>.size)
        withUnsafeMutablePointer(to:&address) { p in p.withMemoryRebound(to:sockaddr.self,capacity:1) { _=getsockname(listener,$0,&length) } }
        var bytes=[UInt8](repeating:0,count:32)
        guard SecRandomCopyBytes(kSecRandomDefault,bytes.count,&bytes)==errSecSuccess else { stop(); throw NSError(domain:"SnowPlay",code:1) }
        policy=HTTPPolicy(port:UInt16(bigEndian:address.sin_port),token:bytes.map { String(format:"%02x",$0) }.joined())
        let descriptor=listener
        queue.async { [weak self] in
            while true {
                let client=accept(descriptor,nil,nil)
                if client < 0 { break }
                self?.serve(client)
                Darwin.close(client)
            }
        }
    }
    private func serve(_ client: Int32) {
        var timeout=timeval(tv_sec:2,tv_usec:0); var noSignal: Int32=1
        setsockopt(client,SOL_SOCKET,SO_RCVTIMEO,&timeout,socklen_t(MemoryLayout.size(ofValue:timeout)))
        setsockopt(client,SOL_SOCKET,SO_SNDTIMEO,&timeout,socklen_t(MemoryLayout.size(ofValue:timeout)))
        setsockopt(client,SOL_SOCKET,SO_NOSIGPIPE,&noSignal,socklen_t(MemoryLayout.size(ofValue:noSignal)))
        var data=Data(), buffer=[UInt8](repeating:0,count:4096)
        let deadline=Date().addingTimeInterval(3)
        while data.count <= 49152 && Date() < deadline {
            let n=recv(client,&buffer,buffer.count,0)
            if n <= 0 { return }
            data.append(contentsOf:buffer.prefix(n))
            if let boundary=data.range(of:Data("\r\n\r\n".utf8)) {
                guard boundary.lowerBound <= 8192 else { send(.json(["error":"headers too large"],status:413),client); return }
                // Incomplete body: continue reading only for a valid bounded Content-Length.
                let head=String(data:data[..<boundary.lowerBound],encoding:.utf8) ?? ""
                let lengths=head.components(separatedBy:"\r\n").dropFirst().filter { $0.lowercased().hasPrefix("content-length:") }
                let size=lengths.first.flatMap { Int($0.dropFirst(15).trimmingCharacters(in:.whitespaces)) } ?? 0
                if size < 0 || size > 32768 { send(.json(["error":"body too large"],status:413),client); return }
                if data.count < boundary.upperBound+size { continue }
                guard let request=HTTPRequest.parse(data) else { send(.json(["error":"invalid request"],status:400),client); return }
                let code=policy.authorize(request)
                guard code == 200 else { send(.json(["error":"request rejected"],status:code),client); return }
                let response=DispatchQueue.main.sync { self.handler?(request) ?? .json(["error":"unavailable"],status:503) }
                send(response,client); return
            } else if data.count>8192 { send(.json(["error":"headers too large"],status:413),client); return }
        }
    }
    private func send(_ response: HTTPResponse, _ fd: Int32) {
        let text="HTTP/1.1 \(response.status) \(response.status == 200 ? "OK" : "Error")\r\nContent-Type: \(response.type)\r\nContent-Length: \(response.body.count)\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nReferrer-Policy: no-referrer\r\nCross-Origin-Resource-Policy: same-origin\r\nContent-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'\r\n\r\n"
        let packet=Data(text.utf8)+response.body
        packet.withUnsafeBytes { bytes in
            var sent=0
            while sent<bytes.count { let n=Darwin.send(fd,bytes.baseAddress!.advanced(by:sent),bytes.count-sent,0); if n<=0 { break }; sent+=n }
        }
    }
    func stop() { if listener >= 0 { shutdown(listener,SHUT_RDWR); Darwin.close(listener); listener = -1 } }
    deinit { stop() }
}
