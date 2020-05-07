import XCTest
@testable import pgm

final class FactorTests: XCTestCase {
    func testExample() {
        guard let phi = Factor(scope: [0, 1, 2, 3], cardinalities: [2, 2, 3, 2]) else {
            XCTFail("Failed to initialize factor.")
            return
        }
        XCTAssert(phi.count == 24)
    }
    
    func testSubscript() {
        guard var phi = Factor(scope: [0, 1, 2], cardinalities: [2, 2, 2]) else {
            XCTFail("Failed to initialize factor.")
            return
        }
        let expected = 5.4
        phi[0, 1, 0] = expected
        let actual = phi[2]
        XCTAssert(actual == expected)
    }
    
    func testArgMax() {
        guard var phi = Factor(scope: [0, 1, 2], cardinalities: [2, 2, 3]) else {
            XCTFail("Failed to initialize factor.")
            return
        }
        let expected = [0, 1, 0]
        phi.set(11.2, forAssignment: expected)
        let actual = phi.argMax()
        XCTAssert(actual == expected)
    }
    
    func testFactorMultiplication() {
        guard
            let p1 = Factor(scope: [0, 1], cardinalities: [3, 2], values: [0.5, 0.1, 0.3, 0.8, 0, 0.9]),
            let p2 = Factor(scope: [1, 2], cardinalities: [2, 2], values: [0.5, 0.1, 0.7, 0.2]) else {
            XCTFail("Failed to initialize factors.")
            return
        }
        
        let expected = Factor(scope: [0, 1, 2], cardinalities: [3, 2, 2], values: [0.25, 0.05, 0.15, 0.08, 0, 0.09, 0.35, 0.07, 0.21, 0.16, 0, 0.18])!
        let actual = p1 * p2
        XCTAssertEqual(expected.count, actual.count)
        XCTAssertEqual(expected.scope, actual.scope)
        XCTAssertEqual(expected.cardinalities, actual.cardinalities)
        for i in 0..<actual.count {
            let error = abs(expected[i] - actual[i])
            XCTAssert(error < 1.0E-16)
        }
    }
    
    func testFactorMarginalization() {
        guard let p1 = Factor(scope: [0, 1, 2], cardinalities: [3, 2, 2], values: [0.25, 0.05, 0.15, 0.08, 0, 0.09, 0.35, 0.07, 0.21, 0.16, 0, 0.18]) else {
            XCTFail("Failed to initialize factor.")
            return
        }
        
        let expected = Factor(scope: [0, 2], cardinalities: [3, 2], values: [0.33, 0.05, 0.24, 0.51, 0.07, 0.39])!
        let actual = p1.marginalize(overVarId: 1)
        XCTAssertEqual(expected.count, actual.count)
        XCTAssertEqual(expected.scope, actual.scope)
        XCTAssertEqual(expected.cardinalities, actual.cardinalities)
        for i in 0..<actual.count {
            let error = abs(expected[i] - actual[i])
            XCTAssert(error < 1.0E-16)
        }
    }
    
    func testBeliefPropagation() {
        let phi2_5 = Factor(scope: [2, 5], cardinalities: [2, 2], values: [10, 1, 1, 10])!
        let delta2_3 = 1.0
        let delta4_3 = 1.0
        let delta7_3 = 1.0
        
        let phi4_5 = Factor(scope: [4, 5], cardinalities: [2, 2], values: [10, 1, 1, 10])!
        let delta1_4 = 1.0
        let delta3_6 = (phi2_5 * delta2_3 * delta4_3 * delta7_3).marginalize(overVarId: 2)
        let b6 = (phi4_5 * delta3_6 * delta1_4).normalize()
        let expected = 0.4545
        let actual = b6[1, 1]
        let error = abs(actual - expected)
        XCTAssert(error <= 0.001)
    }
    
    static var allTests = [
        ("testExample", testExample),
    ]
}
