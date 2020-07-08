//
//  DiffMatchPatch.swift
//  
//
//  Created by Steven W. Klassen on 2020-06-23.
//

import Foundation
import KSSFoundation


/**
 Engine for computing the difference between two strings. This is a Swift port of the Python3 version of the
 code found at https://github.com/google/diff-match-patch.
 */
public struct DiffMatchPatch {
    // MARK: Configuration Parameters

    /// Number of seconds to map a diff before giving up (0 for infinity).
    public var diffTimeout: TimeInterval = duration(1.0, .seconds)

    /// Cost of an empty edit operation in terms of edit characters.
    public var diffEditCost = 4

    /// At what point is no match declared (0.0 = perfection, 1.0 = very loose).
    public var matchThreshold = 0.5

    /**
    How far to search for a match (0 = exact location, 1000+ = broad match).
    A match this many characters away from the expected location will add
    1.0 to the score (0.0 is a perfect match).
     */
    public var matchDistance = 1000

    /**
    When deleting a large block of text (over ~64 characters), how close do
    the contents have to be to match the expected contents. (0.0 = perfection,
    1.0 = very loose).  Note that Match_Threshold controls how closely the
    end points of a delete need to match.
     */
    public var patchDeleteThreshold = 0.5

    /// Chunk size for context length.
    public var patchMargin = 4


    // The number of bits in an int.
    // Python has no maximum, thus to disable patch splitting set to 0.
    // However to avoid long patches in certain pathological cases, use 32.
    // Multiple short patches (using native ints) are much faster than long ones.
    //
    // KSS Note: we are using 64 bit hardware, but are going to leave this at 32 for
    // now until we better understand exactly what it does.
    var matchMaxBits = 32


    // MARK: Implementation

    /**
     Find the differences between two texts, and return it as an array of difference descriptions. Note that
     you are not passing in two `String` values, but rather two `Substring` values that should be
     substrings representing the entire strings. The reason for this is to make the recursion a bit easier.

     - parameters:
        - text1in: The "old" string of the difference.
        - text2in: The "new" string of the difference.
        - deadline: Optional time when the diff should be complete by.  Used internally for recursive calls.  Users should set `diffTimeout` instead.

     - returns: An array of the difference descriptions.
     */
    public func main(_ text1in: Substring,
                     _ text2in: Substring,
                     _ deadline1: Date? = nil) -> [Difference]
    {
        var text1 = text1in
        var text2 = text2in

        // Set a deadline by which time the diff must be complete.
        let deadline = deadline1 ?? (diffTimeout <= 0 ? Date.distantFuture : Date() + diffTimeout)

        // Check for equality (speedup).
        if text1 == text2 {
            return [Difference(inOriginal: text1, inNew: text2)]
        }

        // Trim off common prefix (speedup).
        var commonprefix = Substring()
        var commonprefix2 = Substring()
        var commonlength = commonPrefix(text1, text2)
        if commonlength > 0 {
            (commonprefix, text1) = text1.partition(after: commonlength)
            (commonprefix2, text2) = text2.partition(after: commonlength)
        }

        // Trim off common suffix (speedup).
        var commonsuffix = Substring()
        var commonsuffix2 = Substring()
        commonlength = commonSuffix(text1, text2)
        if commonlength > 0 {
            (text1, commonsuffix) = text1.partition(after: -commonlength)
            (text2, commonsuffix2) = text2.partition(after: -commonlength)
        }

        // Compute the diff on the middle block.
        var diffs = compute(text1, text2, deadline)

        // Restore the prefix and suffix.
        if !commonprefix.isEmpty {
            precondition(commonprefix.count == commonprefix2.count)
            diffs.insert(Difference(inOriginal: commonprefix, inNew: commonprefix2), at: 0)
        }
        if !commonsuffix.isEmpty {
            precondition(commonsuffix.count == commonsuffix2.count)
            diffs.append(Difference(inOriginal: commonsuffix, inNew: commonsuffix2))
        }
        cleanupMerge(&diffs)
        return diffs
    }

    //    Find the differences between two texts.  Assumes that the texts do not
    //      have any common prefix or suffix.
    //
    //    Args:
    //      text1: Old string to be diffed.
    //      text2: New string to be diffed.
    //      checklines: Speedup flag.  If false, then don't run a line-level diff
    //        first to identify the changed areas.
    //        If true, then run a faster, slightly less optimal diff.
    //      deadline: Time when the diff should be complete by.
    //
    //    Returns:
    //      Array of changes.
    func compute(_ text1: Substring, _ text2: Substring, /*_ checklines: Bool,*/ _ deadline: Date) -> [Difference] {
        if text1.isEmpty {
            // Just add some text (speedup).
            return [Difference(inNew: text2)]
        }

        if text2.isEmpty {
            // Just delete some text (speedup).
            return [Difference(inOriginal: text1)]
        }

        var longtext = text2
        var shorttext = text1
        var shortTextIsPartOfOldString = true
        if text1.count > text2.count {
            longtext = text1
            shorttext = text2
            shortTextIsPartOfOldString = false
        }

        if let index = longtext.find(shorttext) {
            let index2 = longtext.index(index, offsetBy: shorttext.count)
            // Shorter text is inside the longer text (speedup).
            if shortTextIsPartOfOldString {
                // the prefix and suffix of the long text have been inserted
                return [Difference(inNew: longtext.prefix(upTo: index)),
                        Difference(inOriginal: shorttext, inNew: longtext[index ..< index2]),
                        Difference(inNew: longtext.suffix(from: index2))]
            } else {
                // the prefix and suffix of the long text have been deleted
                return [Difference(inOriginal: longtext.prefix(upTo: index)),
                        Difference(inOriginal: longtext[index ..< index2], inNew: shorttext),
                        Difference(inOriginal: longtext.suffix(from: index2))]
            }
        }

        if shorttext.count == 1 {
            // Single character string.
            // After the previous speedup, the character can't be an equality.
            return [Difference(inOriginal: text1), Difference(inNew: text2)]
        }

        // Check to see if the problem can be split in two.
        if let hm = halfMatch(text1, text2) {
            // A half-match was found, sort out the return data.
            let text1_a = hm[0]
            let text1_b = hm[1]
            let text2_a = hm[2]
            let text2_b = hm[3]
            let text1_common = hm[4]
            let text2_common = hm[5]

            // Send both pairs off for separate processing.
            let diffs_a = main(text1_a, text2_a, /*checklines,*/ deadline)
            let diffs_b = main(text1_b, text2_b, /*checklines,*/ deadline)

            // Merge the results
            var ret = diffs_a
            ret.append(Difference(inOriginal: text1_common, inNew: text2_common))
            ret.append(contentsOf: diffs_b)
            return ret
        }

        return bisect(text1, text2, deadline)
    }


    //    Find the 'middle snake' of a diff, split the problem in two
    //      and return the recursively constructed diff.
    //      See Myers 1986 paper: An O(ND) Difference Algorithm and Its Variations.
    //
    //    Args:
    //      text1: Old string to be diffed.
    //      text2: New string to be diffed.
    //      deadline: Time at which to bail if not yet complete.
    //
    //    Returns:
    //      Array of diff tuples.
    func bisect(_ text1: Substring, _ text2: Substring, _ deadline: Date) -> [Difference] {
        // Cache the text lengths to prevent multiple calls.
        let text1_length = text1.count
        let text2_length = text2.count
        let max_d = floordiv(text1_length + text2_length + 1, 2)
        let v_offset = max_d
        let v_length = 2 * max_d
        var v1 = Array(repeating: -1, count: v_length)
        var v1Indices = Array(repeating: text1.endIndex, count: v_length)
        v1[v_offset + 1] = 0
        v1Indices[v_offset + 1] = text1.startIndex
        var v2 = v1
        let delta = text1_length - text2_length

        // If the total number of characters is odd, then the front path will
        // collide with the reverse path.
        let front = (delta % 2 != 0)

        // Offsets for start and end of k loop.
        // Prevents mapping of space beyond the grid.
        var k1start = 0
        var k1end = 0
        var k2start = 0
        var k2end = 0

        for d in 0 ..< max_d {
            // Bail out if deadline is reached.
            if Date() > deadline {
                break
            }

            // Walk the front path one step.
            var prevY: Int? = nil
            var prevYIdx: Substring.Index? = nil
            for k1 in stride(from: -d + k1start, to: d + 1 - k1end, by: 2) {
                let k1_offset = v_offset + k1
                var x1 = v1[k1_offset - 1]
                var x1idx = v1Indices[k1_offset - 1]
                if (k1 == -d) || (k1 != d && x1 < v1[k1_offset + 1]) {
                    x1 = v1[k1_offset + 1]
                    x1idx = v1Indices[k1_offset + 1]
                } else {
                    x1 += 1
                    if x1idx != text1.endIndex {
                        x1idx = text1.index(x1idx, offsetBy: 1)
                    }
                }

                var y1 = x1 - k1
                var y1idx = text2.endIndex
                if y1 < text2_length {
                    if prevY == nil {
                        y1idx = text2.toIndex(y1)
                    } else {
                        y1idx = text2.index(prevYIdx!, offsetBy: y1 - prevY!)
                    }
                }
                prevY = y1
                prevYIdx = y1idx

                while x1 < text1_length && y1 < text2_length && text1[x1idx] == text2[y1idx] {
                    x1 += 1
                    x1idx = text1.index(x1idx, offsetBy: 1)
                    y1 += 1
                    y1idx = text2.index(y1idx, offsetBy: 1)
                }
                v1[k1_offset] = x1
                v1Indices[k1_offset] = x1idx
                if x1 > text1_length {
                    // Ran off the right of the graph.
                    k1end += 2
                } else if y1 > text2_length {
                    // Ran off the bottom of the graph.
                    k1start += 2
                } else if front {
                    let k2_offset = v_offset + delta - k1
                    if k2_offset >= 0 && k2_offset < v_length && v2[k2_offset] != -1 {
                        // Mirror x2 onto top-left coordinate system.
                        let x2 = text1_length - v2[k2_offset]
                        if x1 >= x2 {
                            // Overlap detected.
                            return bisectSplit(text1, text2, x1idx, y1idx, deadline)
                        }
                    }
                }
            }

            // Walk the reverse path one step.
            prevY = nil
            prevYIdx = nil
            var prevX: Int? = nil
            var prevXIdx: Substring.Index? = nil
            for k2 in stride(from: -d + k2start, to: d + 1 - k2end, by: 2) {
                let k2_offset = v_offset + k2
                var x2 = v2[k2_offset - 1]
                if (k2 != d && x2 < v2[k2_offset + 1]) || (k2 == -d) {
                    x2 = v2[k2_offset + 1]
                } else {
                    x2 += 1
                }
                var y2 = x2 - k2

                var x2idx = text1.endIndex
                if x2 < text1_length {
                    if (prevX == nil) || (prevXIdx == text1.endIndex) {
                        x2idx = text1.toIndex(-x2 - 1)
                    } else {
                        x2idx = text1.index(prevXIdx!, offsetBy: prevX! - x2)
                    }
                }
                prevX = x2
                prevXIdx = x2idx

                var y2idx = text2.endIndex
                if y2 < text2_length {
                    if (prevY == nil) || (prevYIdx == text2.endIndex) {
                        y2idx = text2.toIndex(-y2 - 1)
                    } else {
                        y2idx = text2.index(prevYIdx!, offsetBy: prevY! - y2)
                    }
                }
                prevY = y2
                prevYIdx = y2idx

                while x2 < text1_length && y2 < text2_length && text1[x2idx] == text2[y2idx] {
                    x2 += 1
                    y2 += 1
                    if x2 < (text1_length-1) {
                        x2idx = text1.index(x2idx, offsetBy: -1)
                    }
                    if y2 < (text2_length-1) {
                        y2idx = text2.index(y2idx, offsetBy: -1)
                    }
                }
                v2[k2_offset] = x2
                if x2 > text1_length {
                    // Ran off the left of the graph.
                    k2end += 2
                } else if y2 > text2_length {
                    // Ran off the top of the graph.
                    k2start += 2
                } else if !front {
                    let k1_offset = v_offset + delta - k2
                    if k1_offset >= 0 && k1_offset < v_length && v1[k1_offset] != -1 {
                        let x1 = v1[k1_offset]
                        let x1idx = v1Indices[k1_offset]
                        let y1 = v_offset + x1 - k1_offset
                        // Mirror x2 onto top-left coordinate system.
                        x2 = text1_length - x2
                        if x1 >= x2 {
                            // Overlap detected.
                            return bisectSplit(text1, text2, x1idx, text2.toIndex(y1), deadline)
                        }
                    }
                }
            }
        }

        // Diff took too long and hit the deadline or
        // number of diffs equals number of characters, no commonality at all.
        return [Difference(inOriginal: text1), Difference(inNew: text2)]
    }

    //    Given the location of the 'middle snake', split the diff in two parts
    //    and recurse.
    //
    //    Args:
    //      text1: Old string to be diffed.
    //      text2: New string to be diffed.
    //      x: Index of split point in text1.
    //      y: Index of split point in text2.
    //      deadline: Time at which to bail if not yet complete.
    //
    //    Returns:
    //      Array of diff tuples.
    private func bisectSplit(_ text1: Substring,
                             _ text2: Substring,
                             _ x: Substring.Index,
                             _ y: Substring.Index,
                             _ deadline: Date) -> [Difference]
    {
        // Compute both diffs serially.
        var diffs = main(text1.prefix(upTo: x), text2.prefix(upTo: y), deadline)
        diffs += main(text1.suffix(from: x), text2.suffix(from: y), deadline)
        return diffs
    }

    // Returns the number of characters common to the start of each string.
    func commonPrefix(_ text1: Substring, _ text2: Substring) -> Int {
        if text1.isEmpty || text2.isEmpty || text1.first != text2.first {
            return 0
        }

        // Binary search.
        // Performance analysis: https://neil.fraser.name/news/2007/10/09/
        var pointermin = 0
        var pointermax = min(text1.count, text2.count)
        var pointermid = pointermax
        var pointerstart = 0
        while pointermin < pointermid {
            if text1[pointerstart ..< pointermid] == text2[pointerstart ..< pointermid] {
                pointermin = pointermid
                pointerstart = pointermin
            } else {
                pointermax = pointermid
            }
            pointermid = floordiv(pointermax - pointermin, 2) + pointermin
        }
        return pointermid
    }

    // Returns the number of characters common to the end of each string.
    func commonSuffix(_ text1: Substring, _ text2: Substring) -> Int {
        if text1.isEmpty || text2.isEmpty || text1.last != text2.last {
            return 0
        }

        // Binary search.
        // Performance analysis: https://neil.fraser.name/news/2007/10/09/
        let text1length = text1.count
        let text2length = text2.count
        var pointermin = 0
        var pointermax = min(text1length, text2length)
        var pointermid = pointermax
        var pointerend = 0
        while pointermin < pointermid {
            if (text1[text1length - pointermid ..< text1length - pointerend] == text2[text2length - pointermid ..< text2length - pointerend]) {
                pointermin = pointermid
                pointerend = pointermin
            } else {
                pointermax = pointermid
            }
            pointermid = floordiv(pointermax - pointermin, 2) + pointermin
        }
        return pointermid
    }

    //    Do the two texts share a substring which is at least half the length of
    //    the longer text?
    //    This speedup can produce non-minimal diffs.
    //
    //    Args:
    //      text1: First string.
    //      text2: Second string.
    //
    //    Returns:
    //      Five element Array, containing the prefix of text1, the suffix of text1,
    //      the prefix of text2, the suffix of text2 and the common middle.  Or None
    //      if there was no match.
    func halfMatch(_ text1: Substring, _ text2: Substring) -> [Substring]? {
        if diffTimeout <= 0 {
            // Don't risk returning a non-optimal diff if we have unlimited time.
            return nil
        }

        var longtext = text2
        var shorttext = text1
        if text1.count > text2.count {
            longtext = text1
            shorttext = text2
        }

        if longtext.count < 4 || (shorttext.count * 2) < longtext.count {
            // Pointless
            return nil
        }

        // First check if the second quarter is the seed for a half-match.
        var hm = [Substring]()
        let hm1 = halfMatchI(longtext, shorttext, floordiv(longtext.count + 3, 4))

        // Check again based on the third quarter.
        let hm2 = halfMatchI(longtext, shorttext, floordiv(longtext.count + 1, 2))
        if hm1 == nil && hm2 == nil {
            return nil
        }
        else if hm2 == nil {
            hm = hm1!
        }
        else if hm1 == nil {
            hm = hm2!
        }
        else {
            // Both matched.  Select the longest.
            if hm1![4].count > hm2![4].count {
                hm = hm1!
            }
            else {
                hm = hm2!
            }
        }

        // A half-match was found, sort out the return data.
        if text1.count <= text2.count {
            return [hm[2], hm[3], hm[0], hm[1], hm[5], hm[4]]
        }
        return hm
    }

    //      Does a substring of shorttext exist within longtext such that the
    //      substring is at least half the length of longtext?
    //      Closure, but does not reference any external variables.
    //
    //      Args:
    //        longtext: Longer string.
    //        shorttext: Shorter string.
    //        i: Start index of quarter length substring within longtext.
    //
    //      Returns:
    //        Five element Array, containing the prefix of longtext, the suffix of
    //        longtext, the prefix of shorttext, the suffix of shorttext and the
    //        common middle.  Or None if there was no match.
    //  KSS NOTE: Added a sixth item to the return so that we have the substrings
    //      from both the texts, first the common from the longtext, then the shorttext.
    private func halfMatchI(_ longtext: Substring, _ shorttext: Substring, _ i: Int) -> [Substring]? {
        let seed = longtext[i ..< i + floordiv(longtext.count, 4)]
        var bestcommon = Substring()
        var bestcommon_longtext = Substring()
        var best_longtext_a = Substring()
        var best_longtext_b = Substring()
        var best_shorttext_a = Substring()
        var best_shorttext_b = Substring()
        var jj: Substring.Index? = shorttext.find(seed)
        while jj != nil {
            let j = jj!
            let prefixlength = commonPrefix(longtext.suffix(after: i), shorttext.suffix(from: j))
            let suffixlength = commonSuffix(longtext.prefix(i), shorttext.prefix(upTo: j))
            if bestcommon.count < suffixlength + prefixlength {
                bestcommon = shorttext[shorttext.index(j, offsetBy: -suffixlength) ..< shorttext.index(j, offsetBy: prefixlength)]
                best_longtext_a = longtext.prefix(i - suffixlength)
                best_longtext_b = longtext.suffix(after: i + prefixlength)
                bestcommon_longtext = longtext[i - suffixlength ..< i + prefixlength]
                best_shorttext_a = shorttext.prefix(upTo: shorttext.index(j, offsetBy:  -suffixlength))
                best_shorttext_b = shorttext.suffix(from: shorttext.index(j, offsetBy: prefixlength))
            }
            jj = shorttext.find(seed, from: shorttext.index(j, offsetBy: 1))
        }

        if bestcommon.count * 2 >= longtext.count {
            return [best_longtext_a, best_longtext_b, best_shorttext_a, best_shorttext_b, bestcommon_longtext, bestcommon]
        }
        return nil
    }

    //    Reorder and merge like edit sections.  Merge equalities.
    //    Any edit section can move as long as it doesn't cross an equality.
    //
    //    Args:
    //      diffs: Array of diff tuples.
    func cleanupMerge(_ diffs: inout [Difference]) {
        diffs.append(Difference())      // Add a dummy entry at the end.
        var pointer = 0
        var count_delete = 0
        var count_insert = 0
        var text_delete: Substring? = nil
        var text_insert: Substring? = nil
        while pointer < diffs.count {
            if diffs[pointer].isInsert {
                count_insert += 1
                text_insert = mergeConsecutive(text_insert, appendWith: diffs[pointer].inNew!)
                pointer += 1
            } else if diffs[pointer].isDelete {
                count_delete += 1
                text_delete = mergeConsecutive(text_delete, appendWith: diffs[pointer].inOriginal!)
                pointer += 1
            } else if diffs[pointer].isEqual || diffs[pointer].isEmpty {
                // Upon reaching an equality, check for prior redundancies.
                if count_delete + count_insert > 1 {
                    if count_delete != 0 && count_insert != 0 {
                        // Factor out any common prefixies.
                        var commonlength = commonPrefix(text_insert!, text_delete!)
                        if commonlength != 0 {
                            let x = pointer - count_delete - count_insert - 1
                            let idxInOriginal = text_delete!.toIndex(commonlength)
                            let idxInNew = text_insert!.toIndex(commonlength)
                            if x >= 0 && diffs[x].isEqual {
                                diffs[x].inOriginal = mergeConsecutive(diffs[x].inOriginal,
                                                                       appendWith: text_delete!.prefix(upTo: idxInOriginal))
                                diffs[x].inNew = mergeConsecutive(diffs[x].inNew,
                                                                  appendWith: text_insert!.prefix(upTo: idxInNew))
                            } else {
                                diffs.insert(Difference(inOriginal: text_delete!.prefix(upTo: idxInOriginal),
                                                        inNew: text_insert!.prefix(upTo: idxInNew)),
                                             at: 0)
                                pointer += 1
                            }
                            text_insert = text_insert!.suffix(from: idxInNew)
                            text_delete = text_delete!.suffix(from: idxInOriginal)
                        }

                        // Factor out any common suffixies.
                        commonlength = commonSuffix(text_insert!, text_delete!)
                        if commonlength != 0 {
                            let idxInOriginal = text_delete!.toIndex(-commonlength)
                            let idxInNew = text_insert!.toIndex(-commonlength)
                            if diffs[pointer].isEmpty {
                                diffs[pointer].inOriginal = text_delete!.suffix(from: idxInOriginal)
                                diffs[pointer].inNew = text_insert!.suffix(from: idxInNew)
                            } else {
                                diffs[pointer].inOriginal = mergeConsecutive(text_delete!.suffix(from: idxInOriginal),
                                                                             appendWith: diffs[pointer].inOriginal!)
                                diffs[pointer].inNew = mergeConsecutive(text_insert!.suffix(from: idxInNew),
                                                                        appendWith: diffs[pointer].inNew!)
                            }
                            text_insert = text_insert!.prefix(upTo: idxInNew)
                            text_delete = text_delete!.prefix(upTo: idxInOriginal)
                        }
                    }

                    // Delete the offending records and add the merged ones.
                    var new_ops = [Difference]()
                    if let tDel = text_delete {
                        if !tDel.isEmpty {
                            new_ops.append(Difference(inOriginal: tDel))
                        }
                    }
                    if let tIns = text_insert {
                        if !tIns.isEmpty {
                            new_ops.append(Difference(inNew: tIns))
                        }
                    }
                    pointer -= count_delete + count_insert
                    diffs.replaceSubrange(pointer ..< (pointer + count_delete + count_insert), with: new_ops)
                    pointer += new_ops.count + 1
                } else if pointer != 0 && diffs[pointer - 1].isEqual {
                    // Merge this equality with the previous one.
                    if !diffs[pointer].isEmpty {
                        diffs[pointer - 1].inOriginal = mergeConsecutive(diffs[pointer - 1].inOriginal,
                                                                         appendWith: diffs[pointer].inOriginal!)
                        diffs[pointer - 1].inNew = mergeConsecutive(diffs[pointer - 1].inNew,
                                                                    appendWith: diffs[pointer].inNew!)
                    }
                    diffs.remove(at: pointer)
                } else {
                    pointer += 1
                }

                count_insert = 0
                count_delete = 0
                text_delete = nil
                text_insert = nil
            }
        }

        // Remove the dummy entry at the end.
        if let last = diffs.last {
            if last.isEmpty {
                _ = diffs.popLast()
            }
        }

        // Second pass: look for single edits surrounded on both sides by equalities
        // which can be shifted sideways to eliminate an equality.
        // e.g: A<ins>BA</ins>C -> <ins>AB</ins>AC
        var changes = false
        pointer = 1
        // Intentionally ignore the first and last element (don't need checking).
        while pointer < diffs.count - 1 {
            if diffs[pointer - 1].isEqual && diffs[pointer + 1].isEqual {
                // This is a single edit surrounded by equalities.
                if diffs[pointer].endswith(diffs[pointer - 1].inOriginal!) {
                    // Shift the edit over the previous equality.
                    if diffs[pointer].inOriginal != nil {
                        (diffs[pointer].inOriginal, diffs[pointer+1].inOriginal) = slideEditLeft(diffs[pointer-1].inOriginal!,
                                                                                                 diffs[pointer].inOriginal!,
                                                                                                 diffs[pointer+1].inOriginal!)
                        diffs[pointer+1].inNew = mergeConsecutive(diffs[pointer-1].inNew,
                                                                  appendWith: diffs[pointer+1].inNew!)
                    } else if diffs[pointer].inNew != nil {
                        (diffs[pointer].inNew, diffs[pointer+1].inNew) = slideEditLeft(diffs[pointer-1].inNew!,
                                                                                       diffs[pointer].inNew!,
                                                                                       diffs[pointer+1].inNew!)
                        diffs[pointer+1].inOriginal = mergeConsecutive(diffs[pointer-1].inOriginal,
                                                                       appendWith: diffs[pointer+1].inOriginal!)
                    } else {
                        assert(false)   // should never get here
                    }
                    diffs.remove(at: pointer - 1)
                    changes = true
                } else if diffs[pointer].startswith(diffs[pointer + 1].inOriginal!) {
                    // Shift the edit over the next equality.
                    if diffs[pointer].inOriginal != nil {
                        (diffs[pointer-1].inOriginal, diffs[pointer].inOriginal) = slideEditRight(diffs[pointer-1].inOriginal!,
                                                                                                  diffs[pointer].inOriginal!,
                                                                                                  diffs[pointer+1].inOriginal!)
                        diffs[pointer-1].inNew = mergeConsecutive(diffs[pointer-1].inNew,
                                                                  appendWith: diffs[pointer+1].inNew!)
                    } else if diffs[pointer].inNew != nil {
                        (diffs[pointer-1].inNew, diffs[pointer].inNew) = slideEditRight(diffs[pointer-1].inNew!,
                                                                                        diffs[pointer].inNew!,
                                                                                        diffs[pointer+1].inNew!)
                        diffs[pointer-1].inOriginal = mergeConsecutive(diffs[pointer-1].inOriginal,
                                                                       appendWith: diffs[pointer+1].inOriginal!)
                    } else {
                        assert(false)   // should never get here
                    }
                    diffs.remove(at: pointer + 1)
                    changes = true
                }
            }
            pointer += 1
        }

        // If shifts were made, the diff needs reordering and another shift sweep.
        if changes {
            cleanupMerge(&diffs)
        }
    }

    private func slideEditLeft(_ s1: Substring, _ s2: Substring, _ s3: Substring) -> (Substring, Substring) {
        let splitIdx = s2.index(s2.endIndex, offsetBy: -s1.count)
        assert(String(s1) == String(s2.suffix(from: splitIdx)))
        return (mergeConsecutive(s1, appendWith: s2.prefix(upTo: splitIdx)),
                mergeConsecutive(s2.suffix(from: splitIdx), appendWith: s3))
    }

    private func slideEditRight(_ s1: Substring, _ s2: Substring, _ s3: Substring) -> (Substring, Substring) {
        let splitIdx = s2.toIndex(s3.count)
        assert(String(s2.prefix(upTo: splitIdx)) == String(s3))
        return (mergeConsecutive(s1, appendWith: s2.prefix(upTo: splitIdx)),
                mergeConsecutive(s2.suffix(from: splitIdx), appendWith: s3))
    }
}

/// :nodoc:
extension Difference {
    var isEmpty: Bool { get { return inOriginal == nil && inNew == nil }}

    // Determine if suffix (which should from be an equal) is a suffix of this difference
    // (which should be an edit).
    func endswith(_ suffix: Substring) -> Bool {
        precondition(isDelete || isInsert)      // Only works for edits.
        if let s = inOriginal {
            return s.hasSuffix(suffix)
        }
        if let s = inNew {
            return s.hasSuffix(suffix)
        }
        assert(false)   // Should never reach here
        return false
    }

    func startswith(_ prefix: Substring) -> Bool {
        precondition(isDelete || isInsert)      // Only works for edits.
        if let s = inOriginal {
            return s.hasPrefix(prefix)
        }
        if let s = inNew {
            return s.hasPrefix(prefix)
        }
        assert(false)   // Should never reach here
        return false
    }
}
