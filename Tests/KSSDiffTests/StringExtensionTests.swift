//
//  StringExtensionTests.swift
//  
//
//  Created by Steven W. Klassen on 2020-06-23.
//

import Foundation
import KSSTest
import XCTest

@testable import KSSDiff

final class StringExtensionTests: XCTestCase {
    func testSimpleCases() {
        var diffs = "hello".differencesFrom("hello")
        assertEqual(to: 0) {diffs.count }

        diffs = "hello".differencesFrom("hello world")
        assertEqual(to: 1) { diffs.count }
        assertTrue { diffs[0].isDelete }

        diffs = "hello world".differencesFrom("hello")
        assertEqual(to: 1) { diffs.count }
        assertTrue { diffs[0].isInsert }

        diffs = "there world".differencesFrom("hello there")
        assertEqual(to: 2) { diffs.count }
        assertTrue { diffs[1].isInsert }
        assertTrue { diffs[0].isDelete }
    }
}
