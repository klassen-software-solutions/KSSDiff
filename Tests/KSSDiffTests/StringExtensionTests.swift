//
//  StringExtensionTests.swift
//  
//
//  Created by Steven W. Klassen on 2020-06-23.
//

import Foundation

import XCTest
@testable import KSSDiff

final class StringExtensionTests: XCTestCase {
    func testSimpleCases() {
        var diffs = "hello".differencesFrom("hello")
        XCTAssertEqual(diffs.count, 0)

        diffs = "hello".differencesFrom("hello world")
        XCTAssertEqual(diffs.count, 1)
        XCTAssertTrue(diffs[0].isDelete)

        diffs = "hello world".differencesFrom("hello")
        XCTAssertEqual(diffs.count, 1)
        XCTAssertTrue(diffs[0].isInsert)

        diffs = "there world".differencesFrom("hello there")
        XCTAssertEqual(diffs.count, 2)
        XCTAssertTrue(diffs[1].isInsert)
        XCTAssertTrue(diffs[0].isDelete)
    }

    static var allTests = [
        ("testSimpleCases", testSimpleCases),
    ]
}
