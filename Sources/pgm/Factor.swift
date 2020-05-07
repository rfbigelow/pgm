//
//  Factor.swift
//  pgm
//
//  Created by Robert Bigelow on 5/4/20.
//

/// A multi-dimensional data structure where each dimension represents a discrete random variable.
struct Factor {
    /// The scope of a factor, which is a collection of variable IDs.
    let scope: [Int]
    
    /// The cardinalities of the variables in this factor's scope.
    let cardinalities: [Int]
    
    /// The total number of values contained in this factor.
    let count: Int
    
    /// The stride for each variable.
    private let strides: [Int]
    
    /// The factor's values, which are stored according to a mapping established by the `Factor` type.
    private var values: [Double]
    
    /// Initializes a new factor.
    ///
    /// - Parameter scope: variables that are in scope.
    /// - Parameter cardinalities: carinality of each variable in scope.
    /// - Parameter values: (optional) collection of values to store in the factor.
    ///
    /// - Precondition: The `scope`and `cardinalities` arrays must contain the same number of elements.
    /// - Precondition: If `values` is provided, it must contain the correct number of elements (the product of
    ///                 the cardinalities) and they must be ordered according to the mapping from assignments to indexes.
    init?(scope: [Int], cardinalities: [Int], values: [Double]? = nil) {
        guard scope.count == cardinalities.count else {
            return nil
        }
        
        let n = cardinalities.reduce(1) {$0 * $1}
        if values != nil && values?.count != n {
            return nil
        }
        
        self.count = n
        self.values = values ?? Array(repeating: 0.0, count: n)
        self.scope = scope
        self.cardinalities = cardinalities
        self.strides = cardinalities[0..<(cardinalities.count - 1)].reduce(into: [1]) {$0.append($0.last! * $1)}
    }
    
    subscript(index: Int...) -> Double {
        get {
            let assignmentIndex = getIndex(forAssignment: index)
            return values[assignmentIndex]
        }
        set(newValue) {
            let assignmentIndex = getIndex(forAssignment: index)
            values[assignmentIndex] = newValue
        }
    }
    
    subscript(index: Int) -> Double {
        get {
            return values[index]
        }
        set(newValue) {
            values[index] = newValue
        }
    }
    
    func argMax() -> [Int] {
        var maxIndex = 0
        var max = Double.leastNormalMagnitude
        for (i, x) in values.enumerated() {
            if x > max {
                maxIndex = i
                max = x
            }
        }
        return getAssignment(forIndex: maxIndex)
    }
    
    func getValue(forAssignment assignment: [Int]) -> Double {
        let assignmentIndex = getIndex(forAssignment: assignment)
        return values[assignmentIndex]
    }
    
    mutating func set(_ newValue: Double, forAssignment assignment: [Int]) {
        let assignmentIndex = getIndex(forAssignment: assignment)
        values[assignmentIndex] = newValue
    }
    
    func marginalize(overVarId x: Int) -> Factor {
        var newScope = [Int]()
        var newCardinalities = [Int]()
        var varMap = [Int]()
        var marginStride = 0
        var marginCardinality = 0
        
        for (i, varInScope) in scope.enumerated() {
            if varInScope != x {
                newScope.append(varInScope)
                newCardinalities.append(cardinalities[i])
                varMap.append(i)
            }
            else {
                marginStride = strides[i]
                marginCardinality = cardinalities[i]
            }
        }
        
        // If marginStride wasn't set in the loop above, the margin variable isn't in this factor's scope.
        // In that case we can simply return this factor.
        if marginStride == 0 || marginCardinality == 0 {
            return self
        }
        
        var result = Factor(scope: newScope, cardinalities: newCardinalities)!
        
        var start = 0
        var assignment = Array(repeating: 0, count: scope.count)
        for i in 0..<result.count {
            let marginIndexes = stride(from: start, to: start + marginCardinality * marginStride, by: marginStride)

            // Each entry in the result is the sum of the entries where all other variable assignments match.
            // There are `marginCardinality` of these entries for each entry in the new factor.
            result[i] = marginIndexes.reduce(0.0, { $0 + values[$1] })
            
            // Now the fun part. We need to track where we are in the index into `values`. We could just get the index
            // from the assignment, but that involves a sum product. If we just do a bit of bookkeeping, then we
            // can simply update our starting point.
            var j = 0
            assignment[varMap[j]] += 1
            start += strides[varMap[j]]
            while assignment[varMap[j]] == cardinalities[varMap[j]] {
                assignment[varMap[j]] = 0
                j += 1
                if j >= result.scope.count {
                    break
                }
                assignment[varMap[j]] += 1
                start = assignment[varMap[j]] * strides[varMap[j]]
            }
        }
        
        return result
    }
    
    func normalize() -> Factor {
        let z = values.reduce(0.0, +)
        guard !z.isZero else {
            return self
        }
        let normalized = values.map { $0 / z }
        return Factor(scope: scope, cardinalities: cardinalities, values: normalized)!
    }

    private func getIndex(forAssignment assignment: [Int]) -> Int {
        precondition(assignment.count == strides.count)
        
        return (0..<assignment.count).reduce(0) { $0 + assignment[$1] * strides[$1] }
    }
    
    private func getAssignment(forIndex index: Int) -> [Int] {
        precondition(index >= 0 && index < count)
        
        return (0..<scope.count).map { (index / strides[$0]) % cardinalities[$0] }
    }
    
    private static func combine(_ x: Factor, _ y: Factor) -> (scopes: [Int], cardinalities: [Int], xMap: [Int], yMap: [Int]) {
        var scope: [Int] = []
        var cardinalities: [Int] = []
        var xMap: [Int] = []
        var yMap: [Int] = []
        var varIdLookup: [Int:Int] = [:]
        var scopeSet: Set<Int> = []

        for (i, varId) in x.scope.enumerated() {
            scopeSet.insert(varId)
            scope.append(varId)
            xMap.append(i)
            yMap.append(-1)
            cardinalities.append(x.cardinalities[i])
            varIdLookup[varId] = i
        }
        
        for (i, varId) in y.scope.enumerated() {
            let (inserted, _) = scopeSet.insert(varId)
            if inserted {
                scope.append(varId)
                cardinalities.append(y.cardinalities[i])
                xMap.append(-1)
                yMap.append(i)
            }
            else {
                yMap[varIdLookup[varId]!] = i
            }
        }
        
        return (scope, cardinalities, xMap, yMap)
    }
}

extension Factor {
    static func * (left: Factor, right: Factor) -> Factor {
        let combined = combine(left, right)
        var result = Factor(scope: combined.scopes, cardinalities: combined.cardinalities)!
        
        var j = 0, k = 0
        var assignment = Array(repeating: 0, count: result.scope.count)
        
        for i in 0..<result.count {
            result[i] = left[j] * right[k]
            for l in (0..<assignment.count) {
                let lIndex = combined.xMap[l]
                let rIndex = combined.yMap[l]
                assignment[l] += 1
                if assignment[l] == result.cardinalities[l] {
                    assignment[l] = 0
                    j -= (lIndex == -1) ? 0 : (result.cardinalities[l] - 1) * left.strides[lIndex]
                    k -= (rIndex == -1) ? 0 : (result.cardinalities[l] - 1) * right.strides[rIndex]
                }
                else {
                    j += (lIndex == -1) ? 0 : left.strides[lIndex]
                    k += (rIndex == -1) ? 0 : right.strides[rIndex]
                    break
                }
            }
        }
        return result
    }
    
    static func * (left: Factor, right: Double) -> Factor {
        let scaled = left.values.map { $0 * right }
        return Factor(scope: left.scope, cardinalities: left.cardinalities, values: scaled)!
    }
}

