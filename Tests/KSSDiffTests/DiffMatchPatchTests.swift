//
//  DiffMatchPatchTests.swift
//  
//
//  Created by Steven W. Klassen on 2020-06-23.
//

import XCTest
import KSSFoundation
import KSSTest

@testable import KSSDiff

final class DiffMatchPatchTests: XCTestCase {
    func testConstruction() {
        var dmp = DiffMatchPatch()
        assertEqual(to: 1.0) { dmp.diffTimeout }
        assertEqual(to: 4) { dmp.diffEditCost }
        assertEqual(to: 0.5) { dmp.matchThreshold }
        assertEqual(to: 1000) { dmp.matchDistance }
        assertEqual(to: 0.5) { dmp.patchDeleteThreshold }
        assertEqual(to: 4) { dmp.patchMargin }
        assertEqual(to: 32) { dmp.matchMaxBits }

        dmp = DiffMatchPatch(matchDistance: 500)
        assertEqual(to: 1.0) { dmp.diffTimeout }
        assertEqual(to: 4) { dmp.diffEditCost }
        assertEqual(to: 0.5) { dmp.matchThreshold }
        assertEqual(to: 500) { dmp.matchDistance }
        assertEqual(to: 0.5) { dmp.patchDeleteThreshold }
        assertEqual(to: 4) { dmp.patchMargin }
        assertEqual(to: 32) { dmp.matchMaxBits }
    }

    func testSimpleCases() {
        let dmp = DiffMatchPatch()
        var diffs = dmp.main("hello", "hello")
        assertEqual(to: 1) { diffs.count }
        assertTrue { diffs[0].isEqual }

        diffs = dmp.main("hello world", "hello")
        assertEqual(to: 2) { diffs.count }
        assertTrue { diffs[0].isEqual }
        assertTrue { diffs[1].isDelete }

        diffs = dmp.main("hello", "hello world")
        assertEqual(to: 2) { diffs.count }
        assertTrue { diffs[0].isEqual }
        assertTrue { diffs[1].isInsert }

        diffs = dmp.main("there world", "hello there")
        assertEqual(to: 3) { diffs.count }
        assertTrue { diffs[0].isInsert }
        assertTrue { diffs[1].isEqual }
        assertTrue { diffs[2].isDelete }
    }

    func testCommonPrefix() {
        let dmp = DiffMatchPatch()
        assertEqual(to: 0) { dmp.commonPrefix("abc", "xyz") }
        assertEqual(to: 4) { dmp.commonPrefix("1234abcdef", "1234xyz") }
        assertEqual(to: 4) { dmp.commonPrefix("1234", "1234xyz") }
    }

    func testCommonSuffix() {
        let dmp = DiffMatchPatch()
        assertEqual(to: 0) { dmp.commonSuffix("abc", "xyz") }
        assertEqual(to: 4) { dmp.commonSuffix("abcdef1234", "xyz1234") }
        assertEqual(to: 4) { dmp.commonSuffix("1234", "xyz1234") }
    }

    func testHalfMatch() {
        // Detect a halfmatch.
        var dmp = DiffMatchPatch(diffTimeout: duration(1.0, .seconds))

        // No match.
        assertNil { dmp.halfMatch("1234567890", "abcdef") }
        assertNil { dmp.halfMatch("12345", "23") }

        // Single match.
        assertEqual(to: makeMatch("12", "90", "a", "z", "345678")) {
            dmp.halfMatch("1234567890", "a345678z")
        }
        assertEqual(to: makeMatch("a", "z", "12", "90", "345678")) {
            dmp.halfMatch("a345678z", "1234567890")
        }
        assertEqual(to: makeMatch("abc", "z", "1234", "0", "56789")) {
            dmp.halfMatch("abc56789z", "1234567890")
        }
        assertEqual(to: makeMatch("a", "xyz", "1", "7890", "23456")) {
            dmp.halfMatch("a23456xyz", "1234567890")
        }

        // Check that the common is returning the substring from the correct strings.
        var hm = dmp.halfMatch("1234567890", "a345678z")
        assertEqual(to: "1234567890") { hm![4].base }
        assertEqual(to: "a345678z") { hm![5].base }
        assertEqual(to: hm![5]) { hm![4] }
        hm = dmp.halfMatch("a345678z", "1234567890")
        assertEqual(to: "a345678z") { hm![4].base }
        assertEqual(to: "1234567890") { hm![5].base }
        assertEqual(to: hm![5]) { hm![4] }

        // Multiple Matches.
        assertEqual(to: makeMatch("12123", "123121", "a", "z", "1234123451234")) {
            dmp.halfMatch("121231234123451234123121", "a1234123451234z")
        }
        assertEqual(to: makeMatch("", "-=-=-=-=-=", "x", "", "x-=-=-=-=-=-=-=")) {
            dmp.halfMatch("x-=-=-=-=-=-=-=-=-=-=-=-=", "xx-=-=-=-=-=-=-=")
        }
        assertEqual(to: makeMatch("-=-=-=-=-=", "", "", "y", "-=-=-=-=-=-=-=y")) {
            dmp.halfMatch("-=-=-=-=-=-=-=-=-=-=-=-=y", "-=-=-=-=-=-=-=yy")
        }

        // Non-optimal halfmatch.
        // Optimal diff would be -q+x=H-i+e=lloHe+Hu=llo-Hew+y not -qHillo+x=HelloHe-w+Hulloy
        assertEqual(to: makeMatch("qHillo", "w", "x", "Hulloy", "HelloHe")) {
            dmp.halfMatch("qHilloHelloHew", "xHelloHeHulloy")
        }

        // Optimal no halfmatch.
        dmp.diffTimeout = 0
        assertNil { dmp.halfMatch("qHilloHelloHew", "xHelloHeHulloy") }
    }

    func testCleanupMerge() {
        // Cleanup a messy diff.
        // Null case.
        let dmp = DiffMatchPatch()
        assertEqual(to: 0) {
            var diffs = [Difference]()
            dmp.cleanupMerge(&diffs)
            return diffs.count
        }

        // No change case.
        assertTrue {
            let orig = "ab"
            let new = "ac"
            var diffs = [Difference(inOriginal: orig[0], inNew: new[0]),
                         Difference(inOriginal: orig[1]),
                         Difference(inNew: new[1])]
            dmp.cleanupMerge(&diffs)
            return diffsMatch([DiffValue(type: .equal, value: "a"),
                               DiffValue(type: .delete, value: "b"),
                               DiffValue(type: .insert, value: "c")],
                              diffs)
        }

        // Merge equalities.
        assertTrue {
            let orig = "abc"
            let new = "abc"
            var diffs = [Difference(inOriginal: orig[0], inNew: new[0]),
                         Difference(inOriginal: orig[1], inNew: new[1]),
                         Difference(inOriginal: orig[2], inNew: new[2])]
            dmp.cleanupMerge(&diffs)
            return diffsMatch([DiffValue(type: .equal, value: "abc")], diffs)
        }

        // Merge deletions.
        assertTrue {
            let orig = "abc"
            var diffs = [Difference(inOriginal: orig[0]),
                         Difference(inOriginal: orig[1]),
                         Difference(inOriginal: orig[2])]
            dmp.cleanupMerge(&diffs)
            return diffsMatch([DiffValue(type: .delete, value: "abc")], diffs)
        }

        // Merge insertions.
        assertTrue {
            let new = "abc"
            var diffs = [Difference(inNew: new[0]),
                         Difference(inNew: new[1]),
                         Difference(inNew: new[2])]
            dmp.cleanupMerge(&diffs)
            return diffsMatch([DiffValue(type: .insert, value: "abc")], diffs)
        }

        // Merge interweave.
        assertTrue {
            let orig = "acef"
            let new = "bdef"
            var diffs = [
                Difference(inOriginal: orig[0]),
                Difference(inNew: new[0]),
                Difference(inOriginal: orig[1]),
                Difference(inNew: new[1]),
                Difference(inOriginal: orig[2], inNew: new[2]),
                Difference(inOriginal: orig[3], inNew: new[3])
            ]
            dmp.cleanupMerge(&diffs)
            return diffsMatch([DiffValue(type: .delete, value: "ac"),
                               DiffValue(type: .insert, value: "bd"),
                               DiffValue(type: .equal, value: "ef")],
                              diffs)
        }

        // Prefix and suffix detection.
        assertTrue {
            let orig = "adc"
            let new = "abc"
            var diffs = [
                Difference(inOriginal: orig[0]),
                Difference(inNew: new[0 ..< 3]),
                Difference(inOriginal: orig[1 ..< 3])
            ]
            dmp.cleanupMerge(&diffs)
            return diffsMatch([DiffValue(type: .equal, value: "a"),
                               DiffValue(type: .delete, value: "d"),
                               DiffValue(type: .insert, value: "b"),
                               DiffValue(type: .equal, value: "c")],
                              diffs)
        }

        // Prefix and suffix detection with equalities.
        assertTrue {
            let orig = "xadcy"
            let new = "xabcy"
            var diffs = [
                Difference(inOriginal: orig[0], inNew: new[0]),
                Difference(inOriginal: orig[1]),
                Difference(inNew: new[1 ..< 4]),
                Difference(inOriginal: orig[2 ..< 4]),
                Difference(inOriginal: orig[4], inNew: new[4])
            ]
            dmp.cleanupMerge(&diffs)
            return diffsMatch([DiffValue(type: .equal, value: "xa"),
                               DiffValue(type: .delete, value: "d"),
                               DiffValue(type: .insert, value: "b"),
                               DiffValue(type: .equal, value: "cy")],
                              diffs)
        }

        // Slide edit left.
        assertTrue {
            let orig = "ac"
            let new = "abac"
            var diffs = [
                Difference(inOriginal: orig[0], inNew: new[0]),
                Difference(inNew: new[1 ..< 3]),
                Difference(inOriginal: orig[1], inNew: new[3])
            ]
            dmp.cleanupMerge(&diffs)
            return diffsMatch([DiffValue(type: .insert, value: "ab"),
                               DiffValue(type: .equal, value: "ac")],
                              diffs)
        }

        // Slide edit right.
        assertTrue {
            let orig = "ca"
            let new = "caba"
            var diffs = [
                Difference(inOriginal: orig[0], inNew: new[0]),
                Difference(inNew: new[1 ..< 3]),
                Difference(inOriginal: orig[1], inNew: new[3])
            ]
            dmp.cleanupMerge(&diffs)
            return diffsMatch([DiffValue(type: .equal, value: "ca"),
                               DiffValue(type: .insert, value: "ba")],
                              diffs)
        }

        // Slide edit left recursive.
        assertTrue {
            let orig = "abcacx"
            let new = "acx"
            var diffs = [
                Difference(inOriginal: orig[0], inNew: new[0]),
                Difference(inOriginal: orig[1]),
                Difference(inOriginal: orig[2], inNew: new[1]),
                Difference(inOriginal: orig[3 ..< 5]),
                Difference(inOriginal: orig[5], inNew: new[2])
            ]
            dmp.cleanupMerge(&diffs)
            return diffsMatch([DiffValue(type: .delete, value: "abc"),
                               DiffValue(type: .equal, value: "acx")],
                              diffs)
        }

        // Slide edit right recursive.
        assertTrue {
            let orig = "xcacba"
            let new = "xca"
            var diffs = [
                Difference(inOriginal: orig[0], inNew: new[0]),
                Difference(inOriginal: orig[1 ..< 3]),
                Difference(inOriginal: orig[3], inNew: new[1]),
                Difference(inOriginal: orig[4]),
                Difference(inOriginal: orig[5], inNew: new[2])
            ]
            dmp.cleanupMerge(&diffs)
            return diffsMatch([DiffValue(type: .equal, value: "xca"),
                               DiffValue(type: .delete, value: "cba")],
                              diffs)
        }

        // Empty merge.
        assertTrue {
            let orig = "bc"
            let new = "abc"
            var diffs = [
                Difference(inOriginal: orig[0]),
                Difference(inNew: new[0 ..< 2]),
                Difference(inOriginal: orig[1], inNew: new[2])
            ]
            dmp.cleanupMerge(&diffs)
            return diffsMatch([DiffValue(type: .insert, value: "a"),
                               DiffValue(type: .equal, value: "bc")],
                              diffs)
        }

        // Empty equality.
        assertTrue {
            let orig = "b"
            let new = "ab"
            var diffs = [
                Difference(inOriginal: orig[0 ..< 0], inNew: new[0 ..< 0]),
                Difference(inNew: new[0]),
                Difference(inOriginal: orig[0], inNew: new[1])
            ]
            dmp.cleanupMerge(&diffs)
            return diffsMatch([DiffValue(type: .insert, value: "a"),
                               DiffValue(type: .equal, value: "b")],
                              diffs)
        }
    }

    func testBisect() {
        let dmp = DiffMatchPatch()
        // Normal
        let a = Substring("cat")
        let b = Substring("map")

        // Since the resulting diff hasn't been normalized, it would be ok if
        // the insertion and deletion pairs are swapped.
        // If the order changes, tweak this test as required.
        assertTrue {
            diffsMatch([DiffValue(type: .delete, value: "c"),
                        DiffValue(type: .insert, value: "m"),
                        DiffValue(type: .equal, value: "a"),
                        DiffValue(type: .delete, value: "t"),
                        DiffValue(type: .insert, value: "p")],
                       dmp.bisect(a, b, Date.distantFuture))
        }

        // Timeout.
        assertTrue {
            diffsMatch([DiffValue(type: .delete, value: "cat"),
                        DiffValue(type: .insert, value: "map")],
                       dmp.bisect(a, b, Date.distantPast))
        }
    }
}

fileprivate func makeMatch(_ a: Substring, _ b: Substring, _ c: Substring, _ d: Substring, _ e: Substring) -> [Substring] {
    return [a, b, c, d, e, e]
}

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
