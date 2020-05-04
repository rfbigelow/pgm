import XCTest

import pgmTests

var tests = [XCTestCaseEntry]()
tests += pgmTests.allTests()
XCTMain(tests)
