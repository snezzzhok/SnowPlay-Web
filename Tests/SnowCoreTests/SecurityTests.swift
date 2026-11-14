#if canImport(XCTest)
import XCTest
#else
import Foundation
#endif
@testable import SnowCore
final class SecurityTests: XCTestCase {
    let p=HTTPPolicy(port:45000,token:"secret")
    func request(_ headers: [String:String], method: String = "POST") -> HTTPRequest { HTTPRequest(method:method,path:"/api/config",headers:headers) }
    var valid: [String:String] { ["host":"127.0.0.1:45000","origin":"http://127.0.0.1:45000","x-snowplay-token":"secret","content-type":"application/json"] }
    func testOriginHostTokenAndMethod() {
        XCTAssertEqual(p.authorize(request(valid)),200)
        for (key,value) in [("host","evil.example:45000"),("origin","https://evil.example"),("x-snowplay-token","wrong"),("content-type","text/plain"),("sec-fetch-site","cross-site")] {
            var h=valid; h[key]=value; XCTAssertEqual(p.authorize(request(h)),403)
        }
        var h=valid; h.removeValue(forKey:"origin"); XCTAssertEqual(p.authorize(request(h)),403)
        h=valid; h.removeValue(forKey:"x-snowplay-token"); XCTAssertEqual(p.authorize(request(h)),403)
        XCTAssertEqual(p.authorize(request(valid,method:"DELETE")),405)
        XCTAssertEqual(p.authorize(request(["host":"127.0.0.1:45000"],method:"GET")),200)
    }
    func testParserRejectsSmugglingAndOversize() {
        func parse(_ s: String) -> HTTPRequest? { HTTPRequest.parse(Data(s.utf8)) }
        XCTAssertNotNil(parse("GET / HTTP/1.1\r\nHost: 127.0.0.1:45000\r\n\r\n"))
        XCTAssertNil(parse("GET / HTTP/1.1\r\nHost: a\r\nHost: b\r\n\r\n"))
        XCTAssertNil(parse("POST / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n"))
        XCTAssertNil(parse("POST / HTTP/1.1\r\nContent-Length: 4\r\n\r\n{}"))
        XCTAssertNil(parse("POST / HTTP/1.1\r\nContent-Length: -1\r\n\r\n"))
        XCTAssertNil(parse("GET / HTTP/1.1\r\nHost: a\r\n\r\nGET / HTTP/1.1\r\n\r\n"))
        XCTAssertNil(parse("GET / HTTP/1.1\r\nX: "+String(repeating:"x",count:9000)+"\r\n\r\n"))
    }
}
