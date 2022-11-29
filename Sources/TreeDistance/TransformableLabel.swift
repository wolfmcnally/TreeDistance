import Foundation

public protocol TransformableLabel {
    func transformationCost(operation: TreeOperation, other: Self?) -> Double
}
