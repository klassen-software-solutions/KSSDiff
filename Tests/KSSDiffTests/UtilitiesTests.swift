//
//  UtilitiesTests.swift
//  
//
//  Created by Steven W. Klassen on 2020-06-26.
//

import Foundation

import XCTest
@testable import KSSDiff

final class UtilitiesTests: XCTestCase {
    func testFloordiv() {
        XCTAssertEqual(floordiv(4, 2), 2)
        XCTAssertEqual(floordiv(5, 2), 2)
    }

    func testSubstring() {
        let s = "hello there world"
        let ss = Substring(s)
        XCTAssertEqual(ss[3], "l")
        XCTAssertEqual(ss[2 ..< 5], "llo")
        XCTAssertEqual(ss.suffix(after: 8), "ere world")
        let idx = ss.find("there")
        XCTAssertEqual(ss[idx!], "t")
        XCTAssertNil(ss.find("not there"))
        let idx2 = ss.find("world", from: idx!)
        XCTAssertEqual(ss[idx2!], "w")
        let idx3 = ss.index(idx2!, offsetBy: 1)
        XCTAssertNil(ss.find("world", from: idx3))
        XCTAssertEqual(ss.find(character: "w", from: idx!), idx2)
        XCTAssertNil(ss.find("w", from: idx3))
        XCTAssertNil(ss.findNewline(from: idx!))

        let s2 = Substring("hello\nthere\r\nworld")
        let ix1 = s2.findNewline(from: s2.startIndex)
        XCTAssertNotNil(ix1)
        let ix2 = s2.findNewline(from: s2.index(ix1!, offsetBy: 1))
        XCTAssertNotNil(ix2)
        XCTAssertTrue(ix1! < ix2!)
        XCTAssertNil(s2.findNewline(from: s2.index(ix2!, offsetBy: 1)))
    }

    func testSubstringSingleIndex() {
        let s = Substring("cat")
        XCTAssert(s[0] == "c")
        XCTAssert(s[1] == "a")
        XCTAssert(s[2] == "t")
        XCTAssert(s[-1] == "t")
        XCTAssert(s[-2] == "a")
    }

    func testSubstringSuffix() {
        let s = Substring("hello there world")
        XCTAssertEqual(s.suffix(after: 6), "there world")
        XCTAssertEqual(s.suffix(after: -5), "world")
    }

    func testSubstringPartition() {
        let s = Substring("hello there world")
        var (prefix, suffix) = s.partition(after: 6)
        XCTAssertEqual(prefix, "hello ")
        XCTAssertEqual(suffix, "there world")

        (prefix, suffix) = s.partition(after: -5)
        XCTAssertEqual(prefix, "hello there ")
        XCTAssertEqual(suffix, "world")

        (prefix, suffix) = s.partition(after: 0)
        XCTAssertEqual(prefix, "")
        XCTAssertEqual(suffix, "hello there world")
        XCTAssertTrue(prefix.isEmpty)

        (prefix, suffix) = s.partition(after: -s.count)
        XCTAssertEqual(prefix, "")
        XCTAssertEqual(suffix, "hello there world")
        XCTAssertTrue(prefix.isEmpty)

        (prefix, suffix) = s.partition(after: s.count)
        XCTAssertEqual(prefix, "hello there world")
        XCTAssertEqual(suffix, "")
        XCTAssertTrue(suffix.isEmpty)
    }

    func testMergeConsecutive() {
        let ss = Substring("hello there world")
        let ss1 = ss[1 ..< 4]
        let ss2 = ss[4 ..< 9]
        XCTAssertEqual(mergeConsecutive(ss1, appendWith: ss2), "ello the")
    }

    func testDifferenceEndsWith() {
        var diff = Difference(inNew: Substring("abcd"))
        XCTAssertTrue(diff.endswith("cd"))
        XCTAssertFalse(diff.endswith("cde"))

        diff = Difference(inOriginal: Substring("abcd"))
        XCTAssertTrue(diff.endswith("cd"))
        XCTAssertFalse(diff.endswith("cde"))
    }

    func testDifferenceStartsWith() {
        var diff = Difference(inNew: Substring("abcd"))
        XCTAssertTrue(diff.startswith("ab"))
        XCTAssertFalse(diff.startswith("xab"))

        diff = Difference(inOriginal: Substring("abcd"))
        XCTAssertTrue(diff.startswith("ab"))
        XCTAssertFalse(diff.startswith("xab"))
    }

    static var allTests = [
        ("testFloordiv", testFloordiv),
        ("testSubstring", testSubstring),
        ("testMergeConsecutive", testMergeConsecutive),
    ]
}
