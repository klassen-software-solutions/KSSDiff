//
//  Bug10InitializeErrorTests.swift
//  
//
//  Created by Steven W. Klassen on 2021-09-14.
//

import Foundation

import XCTest
import KSSTest

// Important: do not use @testable in this file as that avoids the bug we are testing
import KSSDiff

final class Bug10InitializeErrorTests: XCTestCase {
    func testPublicConstruction() {
        let newStr = "Hi Hamed"
        let oldStr = "How are you"
        let engine = DiffMatchPatch()
        let diffs = engine.main(Substring(oldStr), Substring(newStr))
        assertTrue { diffs[0].isEqual && diffs[0].inOriginal == "H" }
        assertTrue { diffs[1].isDelete && diffs[1].inOriginal == "ow" }
        assertTrue { diffs[2].isInsert && diffs[2].inNew == "i" }
        assertTrue { diffs[3].isEqual && diffs[3].inOriginal == " " }
        assertTrue { diffs[4].isInsert && diffs[4].inNew == "H" }
        assertTrue { diffs[5].isEqual && diffs[5].inOriginal == "a" }
        assertTrue { diffs[6].isDelete && diffs[6].inOriginal == "r" }
        assertTrue { diffs[7].isInsert && diffs[7].inNew == "m" }
        assertTrue { diffs[8].isEqual && diffs[8].inOriginal == "e" }
        assertTrue { diffs[9].isDelete && diffs[9].inOriginal == " you" }
        assertTrue { diffs[10].isInsert && diffs[10].inNew == "d" }
        assertEqual(to: 11) { diffs.count }
    }
}
