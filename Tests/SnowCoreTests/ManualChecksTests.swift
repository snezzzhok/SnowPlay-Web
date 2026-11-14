#if canImport(XCTest)
import XCTest
#else
import Foundation
#endif
@testable import SnowCore
final class ManualChecksTests: XCTestCase {
    func testProgressPersistsManualFailuresNotesAndPosition() throws {
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let url=directory.appendingPathComponent("settings.checks.json")
        var p=ManualCheckProgress(); p.current=7; p.results["8"]=ManualCheckResult(status:"failed",note:"Секунды не меняются")
        try p.save(to:url); let loaded=ManualCheckProgress.load(from:url)
        XCTAssertEqual(loaded.current,7); XCTAssertEqual(loaded.results["8"]?.status,"failed"); XCTAssertEqual(loaded.results["8"]?.note,"Секунды не меняются")
        XCTAssertNil(loaded.results["9"])
    }
    func testInvalidRecordsNeverBecomePassedChecks() {
        var p=ManualCheckProgress(); p.current=999
        p.results=["1":ManualCheckResult(status:"pending",note:"ещё проверяю"),"2":ManualCheckResult(status:"failed",note:String(repeating:"x",count:2000)),"20":ManualCheckResult(status:"passed",note:""),"03":ManualCheckResult(status:"passed",note:""),"4":ManualCheckResult(status:"automatic",note:"")]
        p.validate(); XCTAssertEqual(p.current,18); XCTAssertEqual(p.results.count,2); XCTAssertEqual(p.results["1"]?.status,"pending"); XCTAssertEqual(p.results["2"]?.note.count,1000)
        XCTAssertTrue(ManualCheckProgress.load(from:URL(fileURLWithPath:"/does-not-exist/snowplay-checks.json")).results.isEmpty)
    }
}
