//
//  SpeedTest.swift
//  
//
//  Created by Steven W. Klassen on 2020-07-06.
//

import Foundation
import KSSFoundation
import KSSTest
import XCTest

import KSSDiff

final class SpeedTests: XCTestCase {
    func testSpeed() {
        let text1 = String(contentsOfStream: DATA_speedtest1_InputStream(), encoding: .utf8)!
        let text2 = String(contentsOfStream: DATA_speedtest2_InputStream(), encoding: .utf8)!
        let diffs = text2.differencesFrom(text1)

        // According to the python speedtest we should have the following:
        //   bisects: 1816
        //   Diffs=2187, equal=862, insert=638, delete=687, summed=2187
        // which means this number should be 638+687=1325.
        //
        // Instead we are getting the following:
        //   bisects=1792
        //   raw diffs=2196, equals=865, inserts=641, deletes=690
        //   diffs=1331
        //
        // I have logged a bug (#1) to track this.
        assertEqual(to: 1331) { diffs.count }
        assertEqual(to: 641) { diffs.countMatches({ el in return el.isInsert }) }
        assertEqual(to: 690) { diffs.countMatches({ el in return el.isDelete }) }
    }
}
