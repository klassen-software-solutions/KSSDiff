//
//  DiffMatchPatchTests.swift
//  
//
//  Created by Steven W. Klassen on 2020-06-23.
//

import XCTest
import KSSFoundation

@testable import KSSDiff

final class DiffMatchPatchTests: XCTestCase {
    func testConstruction() {
        var dmp = DiffMatchPatch()
        XCTAssertEqual(dmp.diffTimeout, 1.0)
        XCTAssertEqual(dmp.diffEditCost, 4)
        XCTAssertEqual(dmp.matchThreshold, 0.5)
        XCTAssertEqual(dmp.matchDistance, 1000)
        XCTAssertEqual(dmp.patchDeleteThreshold, 0.5)
        XCTAssertEqual(dmp.patchMargin, 4)
        XCTAssertEqual(dmp.matchMaxBits, 32)

        dmp = DiffMatchPatch(matchDistance: 500)
        XCTAssertEqual(dmp.diffTimeout, 1.0)
        XCTAssertEqual(dmp.diffEditCost, 4)
        XCTAssertEqual(dmp.matchThreshold, 0.5)
        XCTAssertEqual(dmp.matchDistance, 500)
        XCTAssertEqual(dmp.patchDeleteThreshold, 0.5)
        XCTAssertEqual(dmp.patchMargin, 4)
        XCTAssertEqual(dmp.matchMaxBits, 32)
    }

    func testSimpleCases() {
        let dmp = DiffMatchPatch()
        var diffs = dmp.main("hello", "hello")
        XCTAssertEqual(diffs.count, 1)
        XCTAssertTrue(diffs[0].isEqual)

        diffs = dmp.main("hello world", "hello")
        XCTAssertEqual(diffs.count, 2)
        XCTAssertTrue(diffs[0].isEqual)
        XCTAssertTrue(diffs[1].isDelete)

        diffs = dmp.main("hello", "hello world")
        XCTAssertEqual(diffs.count, 2)
        XCTAssertTrue(diffs[0].isEqual)
        XCTAssertTrue(diffs[1].isInsert)

        diffs = dmp.main("there world", "hello there")
        XCTAssertEqual(diffs.count, 3)
        XCTAssertTrue(diffs[0].isInsert)
        XCTAssertTrue(diffs[1].isEqual)
        XCTAssertTrue(diffs[2].isDelete)
    }

    func testCommonPrefix() {
        let dmp = DiffMatchPatch()
        XCTAssertEqual(dmp.commonPrefix("abc", "xyz"), 0)
        XCTAssertEqual(dmp.commonPrefix("1234abcdef", "1234xyz"), 4)
        XCTAssertEqual(dmp.commonPrefix("1234", "1234xyz"), 4)
    }

    func testCommonSuffix() {
        let dmp = DiffMatchPatch()
        XCTAssertEqual(dmp.commonSuffix("abc", "xyz"), 0)
        XCTAssertEqual(dmp.commonSuffix("abcdef1234", "xyz1234"), 4)
        XCTAssertEqual(dmp.commonSuffix("1234", "xyz1234"), 4)
    }

    func testHalfMatch() {
        // Detect a halfmatch.
        var dmp = DiffMatchPatch(diffTimeout: duration(1.0, .seconds))

        // No match.
        XCTAssertNil(dmp.halfMatch("1234567890", "abcdef"))
        XCTAssertNil(dmp.halfMatch("12345", "23"))

        // Single match.
        XCTAssertEqual(makeMatch("12", "90", "a", "z", "345678"), dmp.halfMatch("1234567890", "a345678z"))
        XCTAssertEqual(makeMatch("a", "z", "12", "90", "345678"), dmp.halfMatch("a345678z", "1234567890"))
        XCTAssertEqual(makeMatch("abc", "z", "1234", "0", "56789"), dmp.halfMatch("abc56789z", "1234567890"))
        XCTAssertEqual(makeMatch("a", "xyz", "1", "7890", "23456"), dmp.halfMatch("a23456xyz", "1234567890"))

        // Check that the common is returning the substring from the correct strings.
        var hm = dmp.halfMatch("1234567890", "a345678z")
        XCTAssertEqual(hm![4].base, "1234567890")
        XCTAssertEqual(hm![5].base, "a345678z")
        XCTAssertEqual(hm![4], hm![5])
        hm = dmp.halfMatch("a345678z", "1234567890")
        XCTAssertEqual(hm![4].base, "a345678z")
        XCTAssertEqual(hm![5].base, "1234567890")
        XCTAssertEqual(hm![4], hm![5])

        // Multiple Matches.
        XCTAssertEqual(makeMatch("12123", "123121", "a", "z", "1234123451234"), dmp.halfMatch("121231234123451234123121", "a1234123451234z"))
        XCTAssertEqual(makeMatch("", "-=-=-=-=-=", "x", "", "x-=-=-=-=-=-=-="), dmp.halfMatch("x-=-=-=-=-=-=-=-=-=-=-=-=", "xx-=-=-=-=-=-=-="))
        XCTAssertEqual(makeMatch("-=-=-=-=-=", "", "", "y", "-=-=-=-=-=-=-=y"), dmp.halfMatch("-=-=-=-=-=-=-=-=-=-=-=-=y", "-=-=-=-=-=-=-=yy"))

        // Non-optimal halfmatch.
        // Optimal diff would be -q+x=H-i+e=lloHe+Hu=llo-Hew+y not -qHillo+x=HelloHe-w+Hulloy
        XCTAssertEqual(makeMatch("qHillo", "w", "x", "Hulloy", "HelloHe"), dmp.halfMatch("qHilloHelloHew", "xHelloHeHulloy"))

        // Optimal no halfmatch.
        dmp.diffTimeout = 0
        XCTAssertNil(dmp.halfMatch("qHilloHelloHew", "xHelloHeHulloy"))
    }

//    func testLinesToChars() {
//        // Convert lines down to characters.
//        let dmp = DiffMatchPatch()
//        XCTAssertTrue({ linesMatch("\u{1}\u{2}\u{1}", "\u{2}\u{1}\u{2}", ["", "alpha\n", "beta\n"],
//                                   dmp.linesToChars("alpha\nbeta\nalpha\n", "beta\nalpha\nbeta\n")) }())
//        XCTAssertTrue({ linesMatch("", "\u{1}\u{2}\u{3}\u{3}", ["", "alpha\r\n", "beta\r\n", "\r\n"],
//                                   dmp.linesToChars("", "alpha\r\nbeta\r\n\r\n\r\n")) }())
//        XCTAssertTrue({ linesMatch("\u{1}", "\u{2}", ["", "a", "b"], dmp.linesToChars("a", "b")) }())
//
//        // More than 256 to reveal any 8-bit limitations.
//        let n = 300
//        var lineList = [String]()
//        var charList = [Character]()
//        for i in 1...n {
//            lineList.append("\(i)\n")
//            charList.append(chr(i))
//        }
//        assert(lineList.count == n)
//        let lines = Substring(lineList.joined())
//        let chars = String(charList)
//        assert(chars.count == n)
//        lineList.insert("", at: 0)
//        XCTAssertTrue({ linesMatch(chars, "", lineList, dmp.linesToChars(lines, "")) }())
//    }

    func testCleanupMerge() {
        // Cleanup a messy diff.
        // Null case.
        let dmp = DiffMatchPatch()
        var diffs = [Difference]()
        dmp.cleanupMerge(&diffs)
        XCTAssertEqual(diffs.count, 0)

        // No change case.
        var orig = "ab"
        var new = "ac"
        diffs = [Difference(inOriginal: orig[0], inNew: new[0]),
                 Difference(inOriginal: orig[1]),
                 Difference(inNew: new[1])]
        dmp.cleanupMerge(&diffs)
        XCTAssertTrue({
            diffsMatch([DiffValue(type: .equal, value: "a"),
                        DiffValue(type: .delete, value: "b"),
                        DiffValue(type: .insert, value: "c")],
                       diffs)
            }())

        // Merge equalities.
        orig = "abc"
        new = "abc"
        diffs = [Difference(inOriginal: orig[0], inNew: new[0]),
                 Difference(inOriginal: orig[1], inNew: new[1]),
                 Difference(inOriginal: orig[2], inNew: new[2])]
        dmp.cleanupMerge(&diffs)
        XCTAssertTrue({ diffsMatch([DiffValue(type: .equal, value: "abc")], diffs) }())

        // Merge deletions.
        orig = "abc"
        diffs = [Difference(inOriginal: orig[0]),
                 Difference(inOriginal: orig[1]),
                 Difference(inOriginal: orig[2])]
        dmp.cleanupMerge(&diffs)
        XCTAssertTrue({ diffsMatch([DiffValue(type: .delete, value: "abc")], diffs) }())

        // Merge insertions.
        new = "abc"
        diffs = [Difference(inNew: new[0]),
                 Difference(inNew: new[1]),
                 Difference(inNew: new[2])]
        dmp.cleanupMerge(&diffs)
        XCTAssertTrue({ diffsMatch([DiffValue(type: .insert, value: "abc")], diffs) }())

        // Merge interweave.
        orig = "acef"
        new = "bdef"
        diffs = [
            Difference(inOriginal: orig[0]),
            Difference(inNew: new[0]),
            Difference(inOriginal: orig[1]),
            Difference(inNew: new[1]),
            Difference(inOriginal: orig[2], inNew: new[2]),
            Difference(inOriginal: orig[3], inNew: new[3])
        ]
        dmp.cleanupMerge(&diffs)
        XCTAssertTrue({
            diffsMatch([DiffValue(type: .delete, value: "ac"),
                        DiffValue(type: .insert, value: "bd"),
                        DiffValue(type: .equal, value: "ef")],
                       diffs)
            }())

        // Prefix and suffix detection.
        orig = "adc"
        new = "abc"
        diffs = [
            Difference(inOriginal: orig[0]),
            Difference(inNew: new[0 ..< 3]),
            Difference(inOriginal: orig[1 ..< 3])
        ]
        dmp.cleanupMerge(&diffs)
        XCTAssertTrue({
            diffsMatch([DiffValue(type: .equal, value: "a"),
                        DiffValue(type: .delete, value: "d"),
                        DiffValue(type: .insert, value: "b"),
                        DiffValue(type: .equal, value: "c")],
                       diffs)
        }())

        // Prefix and suffix detection with equalities.
        orig = "xadcy"
        new = "xabcy"
        diffs = [
            Difference(inOriginal: orig[0], inNew: new[0]),
            Difference(inOriginal: orig[1]),
            Difference(inNew: new[1 ..< 4]),
            Difference(inOriginal: orig[2 ..< 4]),
            Difference(inOriginal: orig[4], inNew: new[4])
        ]
        dmp.cleanupMerge(&diffs)
        XCTAssertTrue({
            diffsMatch([DiffValue(type: .equal, value: "xa"),
                        DiffValue(type: .delete, value: "d"),
                        DiffValue(type: .insert, value: "b"),
                        DiffValue(type: .equal, value: "cy")],
                       diffs)
        }())

        // Slide edit left.
        orig = "ac"
        new = "abac"
        diffs = [
            Difference(inOriginal: orig[0], inNew: new[0]),
            Difference(inNew: new[1 ..< 3]),
            Difference(inOriginal: orig[1], inNew: new[3])
        ]
        dmp.cleanupMerge(&diffs)
        XCTAssertTrue({
            diffsMatch([DiffValue(type: .insert, value: "ab"),
                        DiffValue(type: .equal, value: "ac")],
                       diffs)
            }())

        // Slide edit right.
        orig = "ca"
        new = "caba"
        diffs = [
            Difference(inOriginal: orig[0], inNew: new[0]),
            Difference(inNew: new[1 ..< 3]),
            Difference(inOriginal: orig[1], inNew: new[3])
        ]
        dmp.cleanupMerge(&diffs)
        XCTAssertTrue({
            diffsMatch([DiffValue(type: .equal, value: "ca"),
                        DiffValue(type: .insert, value: "ba")],
                       diffs)
            }())

        // Slide edit left recursive.
        orig = "abcacx"
        new = "acx"
        diffs = [
            Difference(inOriginal: orig[0], inNew: new[0]),
            Difference(inOriginal: orig[1]),
            Difference(inOriginal: orig[2], inNew: new[1]),
            Difference(inOriginal: orig[3 ..< 5]),
            Difference(inOriginal: orig[5], inNew: new[2])
        ]
        dmp.cleanupMerge(&diffs)
        XCTAssertTrue({
            diffsMatch([DiffValue(type: .delete, value: "abc"),
                        DiffValue(type: .equal, value: "acx")],
                       diffs)
            }())

        // Slide edit right recursive.
        orig = "xcacba"
        new = "xca"
        diffs = [
            Difference(inOriginal: orig[0], inNew: new[0]),
            Difference(inOriginal: orig[1 ..< 3]),
            Difference(inOriginal: orig[3], inNew: new[1]),
            Difference(inOriginal: orig[4]),
            Difference(inOriginal: orig[5], inNew: new[2])
        ]
        dmp.cleanupMerge(&diffs)
        XCTAssertTrue({
            diffsMatch([DiffValue(type: .equal, value: "xca"),
                        DiffValue(type: .delete, value: "cba")],
                       diffs)
            }())

        // Empty merge.
        orig = "bc"
        new = "abc"
        diffs = [
            Difference(inOriginal: orig[0]),
            Difference(inNew: new[0 ..< 2]),
            Difference(inOriginal: orig[1], inNew: new[2])
        ]
        dmp.cleanupMerge(&diffs)
        XCTAssertTrue({
            diffsMatch([DiffValue(type: .insert, value: "a"),
                        DiffValue(type: .equal, value: "bc")],
                       diffs)
            }())

        // Empty equality.
        orig = "b"
        new = "ab"
        diffs = [
            Difference(inOriginal: orig[0 ..< 0], inNew: new[0 ..< 0]),
            Difference(inNew: new[0]),
            Difference(inOriginal: orig[0], inNew: new[1])
        ]
        dmp.cleanupMerge(&diffs)
        XCTAssertTrue({
            diffsMatch([DiffValue(type: .insert, value: "a"),
                        DiffValue(type: .equal, value: "b")],
                       diffs)
            }())
    }

    func testBisect() {
        let dmp = DiffMatchPatch()
        // Normal
        let a = Substring("cat")
        let b = Substring("map")

        // Since the resulting diff hasn't been normalized, it would be ok if
        // the insertion and deletion pairs are swapped.
        // If the order changes, tweak this test as required.
        XCTAssertTrue({
            diffsMatch([DiffValue(type: .delete, value: "c"),
                        DiffValue(type: .insert, value: "m"),
                        DiffValue(type: .equal, value: "a"),
                        DiffValue(type: .delete, value: "t"),
                        DiffValue(type: .insert, value: "p")],
                       dmp.bisect(a, b, Date.distantFuture))
            }())

        // Timeout.
        XCTAssertTrue({
            diffsMatch([DiffValue(type: .delete, value: "cat"),
                        DiffValue(type: .insert, value: "map")],
                       dmp.bisect(a, b, Date.distantPast))
        }())
    }


//    static var allTests = [
//        ("testConstruction", testConstruction),
//        ("testSimpleCases", testSimpleCases),
//        ("testCommonPrefix", testCommonPrefix),
//    ]
}

fileprivate func makeMatch(_ a: Substring, _ b: Substring, _ c: Substring, _ d: Substring, _ e: Substring) -> [Substring] {
    return [a, b, c, d, e, e]
}

//fileprivate func makeLines(_ s1: String, _ s2: String, _ sa: [String]) -> (String, String, [Substring]) {
//    return (s1, s2, sa.map { Substring($0) })
//}
//
//fileprivate func linesMatch(_ s1: String, _ s2: String, _ sa: [String], _ dmpres: (String, String, [Substring])) -> Bool {
//    guard s1 == dmpres.0 && s2 == dmpres.1 else {
//        return false
//    }
//    guard sa.count == dmpres.2.count else {
//        return false
//    }
//    for (index, element) in sa.enumerated() {
//        if dmpres.2[index] != element {
//            return false
//        }
//    }
//    return true
//}

fileprivate enum DifferenceType {
    case delete
    case insert
    case equal
}

fileprivate struct DiffValue {
    var type: DifferenceType
    var value: String
}

fileprivate func diffsMatch(_ testValues: [DiffValue], _ results: [Difference]) -> Bool {
    guard testValues.count == results.count else {
        return false
    }

    for (index, value) in testValues.enumerated() {
        let result = results[index]
        switch value.type {
        case .delete:
            if !result.isDelete || result.inOriginal! != value.value {
                return false
            }
        case .insert:
            if !result.isInsert || result.inNew! != value.value {
                return false
            }
        case .equal:
            if !result.isEqual || result.inOriginal! != value.value || result.inNew! != value.value {
                return false
            }
        }
    }
    return true
}

fileprivate extension String {
    subscript (i: Int) -> Substring {
        return self[i ..< i + 1]
    }

    subscript (r: Range<Int>) -> Substring {
        let range = Range(uncheckedBounds: (lower: Swift.max(0, Swift.min(count, r.lowerBound)),
                                            upper: Swift.min(count, Swift.max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return self[start ..< end]
    }
}
