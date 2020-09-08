//
//  UtilitiesTests.swift
//  
//
//  Created by Steven W. Klassen on 2020-06-26.
//

import Foundation
import KSSTest
import XCTest

@testable import KSSDiff

final class UtilitiesTests: XCTestCase {
    func testFloordiv() {
        assertEqual(to: 2) { floordiv(4, 2) }
        assertEqual(to: 2) { floordiv(5, 2) }
    }

    func testSubstring() {
        let s = "hello there world"
        let ss = Substring(s)
        assertEqual(to: "l") { ss[3] }
        assertEqual(to: "llo") { ss[2 ..< 5] }
        assertEqual(to: "ere world") { ss.suffix(after: 8) }
        let idx = ss.find("there")
        assertEqual(to: "t") { ss[idx!] }
        assertNil { ss.find("not there") }
        let idx2 = ss.find("world", from: idx!)
        assertEqual(to: "w") { ss[idx2!] }
        let idx3 = ss.index(idx2!, offsetBy: 1)
        assertNil { ss.find("world", from: idx3) }
        assertEqual(to: idx2) { ss.find(character: "w", from: idx!) }
        assertNil { ss.find("w", from: idx3) }
        assertNil { ss.findNewline(from: idx!) }

        let s2 = Substring("hello\nthere\r\nworld")
        let ix1 = s2.findNewline(from: s2.startIndex)
        assertNotNil { ix1 }
        let ix2 = s2.findNewline(from: s2.index(ix1!, offsetBy: 1))
        assertNotNil { ix2 }
        assertTrue { ix1! < ix2! }
        assertNil { s2.findNewline(from: s2.index(ix2!, offsetBy: 1)) }
    }

    func testSubstringSingleIndex() {
        let s = Substring("cat")
        assertEqual(to: "c") { s[0] }
        assertEqual(to: "a") { s[1] }
        assertEqual(to: "t") { s[2] }
        assertEqual(to: "t") { s[-1] }
        assertEqual(to: "a") { s[-2] }
    }

    func testSubstringSuffix() {
        let s = Substring("hello there world")
        assertEqual(to: "there world") { s.suffix(after: 6) }
        assertEqual(to: "world") { s.suffix(after: -5) }
    }

    func testSubstringPartition() {
        let s = Substring("hello there world")
        var (prefix, suffix) = s.partition(after: 6)
        assertEqual(to: "hello ") { prefix }
        assertEqual(to: "there world") { suffix }

        (prefix, suffix) = s.partition(after: -5)
        assertEqual(to: "hello there ") { prefix }
        assertEqual(to: "world") { suffix }

        (prefix, suffix) = s.partition(after: 0)
        assertEqual(to: "") { prefix }
        assertEqual(to: "hello there world") { suffix }
        assertTrue { prefix.isEmpty }

        (prefix, suffix) = s.partition(after: -s.count)
        assertEqual(to: "") { prefix }
        assertEqual(to: "hello there world") { suffix }
        assertTrue { prefix.isEmpty }

        (prefix, suffix) = s.partition(after: s.count)
        assertEqual(to: "hello there world") { prefix }
        assertEqual(to: "") { suffix }
        assertTrue { suffix.isEmpty }
    }

    func testMergeConsecutive() {
        assertEqual(to: Substring("ello the")) {
            let ss = Substring("hello there world")
            let ss1 = ss[1 ..< 4]
            let ss2 = ss[4 ..< 9]
            return mergeConsecutive(ss1, appendWith: ss2)
        }
    }

    func testDifferenceEndsWith() {
        var diff = Difference(inNew: Substring("abcd"))
        assertTrue { diff.endswith("cd") }
        assertFalse { diff.endswith("cde") }

        diff = Difference(inOriginal: Substring("abcd"))
        assertTrue { diff.endswith("cd") }
        assertFalse { diff.endswith("cde") }
    }

    func testDifferenceStartsWith() {
        var diff = Difference(inNew: Substring("abcd"))
        assertTrue { diff.startswith("ab") }
        assertFalse { diff.startswith("xab") }

        diff = Difference(inOriginal: Substring("abcd"))
        assertTrue { diff.startswith("ab") }
        assertFalse { diff.startswith("xab") }
    }
}
