//
//  Difference.swift
//  
//
//  Created by Steven W. Klassen on 2020-06-23.
//

import Foundation

/**
 Describe a single difference between two strings.
 */
public struct Difference {
    /// The substring of the difference in the original string.
    public var inOriginal: Substring? = nil

    /// The substring of the difference in the new string.
    public var inNew: Substring? = nil

    /// Returns `true` if the difference is a deletion. In this case `inOriginal` will be valid and `inNew` will be `nil`.
    public var isDelete: Bool { get { return inOriginal != nil && inNew == nil }}

    /// Returns `true` if the difference is an insertion. In this case `inNew` will be valid and `inOriginal` will be `nil`.
    public var isInsert: Bool { get { return inOriginal == nil && inNew != nil }}

    /// Returns `true` if the difference is a equality. In this case both `inOriginal` and `inNew` will be valid.
    public var isEqual: Bool { get { return inOriginal != nil && inNew != nil }}
}
