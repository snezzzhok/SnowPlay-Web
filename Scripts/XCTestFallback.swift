// Tiny assertion adapter, only used on Command Line Tools hosts without XCTest.
// It runs the exact test methods from Tests/SnowCoreTests, not a second test implementation.
import Foundation
class XCTestCase {}
var assertionFailures=0
func fail(_ message: String, file: StaticString, line: UInt) { assertionFailures+=1; print("FAIL \(file):\(line) \(message)") }
func XCTAssertTrue(_ value: @autoclosure ()->Bool, file: StaticString = #filePath, line: UInt = #line) { if !value() { fail("expected true",file:file,line:line) } }
func XCTAssertFalse(_ value: @autoclosure ()->Bool, file: StaticString = #filePath, line: UInt = #line) { if value() { fail("expected false",file:file,line:line) } }
func XCTAssertEqual<T: Equatable>(_ a: @autoclosure ()->T, _ b: @autoclosure ()->T, file: StaticString = #filePath, line: UInt = #line) { let x=a(),y=b(); if x != y { fail("\(x) != \(y)",file:file,line:line) } }
func XCTAssertEqual(_ a: Double, _ b: Double, accuracy: Double, file: StaticString = #filePath, line: UInt = #line) { if abs(a-b)>accuracy { fail("\(a) != \(b) ± \(accuracy)",file:file,line:line) } }
func XCTAssertGreaterThan<T: Comparable>(_ a: T, _ b: T, file: StaticString = #filePath, line: UInt = #line) { if !(a>b) { fail("\(a) <= \(b)",file:file,line:line) } }
func XCTAssertLessThan<T: Comparable>(_ a: T, _ b: T, file: StaticString = #filePath, line: UInt = #line) { if !(a<b) { fail("\(a) >= \(b)",file:file,line:line) } }
func XCTAssertNil<T>(_ a: T?, file: StaticString = #filePath, line: UInt = #line) { if a != nil { fail("expected nil",file:file,line:line) } }
func XCTAssertNotNil<T>(_ a: T?, file: StaticString = #filePath, line: UInt = #line) { if a == nil { fail("unexpected nil",file:file,line:line) } }
func XCTAssertGreaterThanOrEqual<T:Comparable>(_ a:T,_ b:T,file:StaticString = #filePath,line:UInt = #line){if a<b {fail("\(a) < \(b)",file:file,line:line)}}
func XCTAssertLessThanOrEqual<T:Comparable>(_ a:T,_ b:T,file:StaticString = #filePath,line:UInt = #line){if a>b {fail("\(a) > \(b)",file:file,line:line)}}
func XCTAssertNotEqual<T:Equatable>(_ a:T,_ b:T,file:StaticString = #filePath,line:UInt = #line){if a==b {fail("unexpected equality",file:file,line:line)}}
