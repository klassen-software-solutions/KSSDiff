//
//  Utilities.swift
//  
//
//  Created by Steven W. Klassen on 2020-06-25.
//

import Foundation


// Utilities internal to this package. They are primarily used to ease the translation
// from Python to Swift.


func floordiv(_ numerator: Int, _ denominator: Int) -> Int {
    return Int(floor(Double(numerator) / Double(denominator)))
}


// Adapted from https://stackoverflow.com/questions/24092884/get-nth-character-of-a-string-in-swift-programming-language
// This was added to make the translation from Python a little easier
/// :nodoc:
extension Substring {
    // Return a single character by integer index. Note that we interpret a negative index
    // as a character starting from the end in order to match the Python indexing.
    subscript (i: Int) -> Character {
        return self[toIndex(i)]
    }

    subscript (r: Range<Int>) -> Substring {
        let range = Range(uncheckedBounds: (lower: Swift.max(0, Swift.min(count, r.lowerBound)),
                                            upper: Swift.min(count, Swift.max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return self[start ..< end]
    }

    func toIndex(_ i: Int) -> Substring.Index {
        if i == 0 {
            return startIndex
        } else if i > 0 {
            return index(startIndex, offsetBy: i)
        } else {
            return index(endIndex, offsetBy: i)
        }
    }

    // Return the suffix starting with the given index. Note that we interpret a negative
    // index as the index from the end in order to match the Python indexing.
    func suffix(after i: Int) -> Substring {
        if i >= 0 {
            return self[i ..< count]
        }
        let fromEnd = count + i
        return self[fromEnd ..< count]
    }

    // Partition the string into a prefix and suffix at the given point. Note that the
    // character at the position will be included in the suffix. If the index is negative,
    // then it is an offset from the end of each string.
    func partition(after i: Int) -> (prefix: Substring, suffix: Substring) {
        precondition(abs(i) <= count, "Index must refer to a position in the string.")
        let idx = index((i >= 0 ? startIndex : endIndex), offsetBy: i)
        return (prefix(upTo: idx), suffix(from: idx))
    }

    func find(_ str: Substring) -> Substring.Index? {
        return range(of: str)?.lowerBound
    }

    func find(_ str: Substring, from idx: Substring.Index) -> Substring.Index? {
        let substr = self[idx...]
        return substr.range(of: str)?.lowerBound
    }

    func find(character char: Character, from idx: Substring.Index) -> Substring.Index? {
        let substr = self[idx...]
        return substr.firstIndex(of: char)
    }

    func findNewline(from idx: Substring.Index) -> Substring.Index? {
        let substr = self[idx...]
        return substr.rangeOfCharacter(from: CharacterSet.newlines)?.lowerBound
    }
}

func mergeConsecutive(_ s1: Substring?, appendWith s2: Substring) -> Substring {
    if let s1 = s1 {
        precondition(s1.base == s2.base, "Can only merge substrings of the same string")
        precondition(s1.endIndex == s2.startIndex, "Substrings to merge must be consecutive")
        return s1.base[s1.startIndex ..< s2.endIndex]
    }
    assert(s1 == nil)
    return s2
}
