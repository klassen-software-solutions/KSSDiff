import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(DiffMatchPatchTests.allTests),
        testCase(StringExtensionTests.allTests),
    ]
}
#endif
