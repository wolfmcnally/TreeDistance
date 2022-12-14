import Foundation
import OrderedCollections

public protocol TreeNodeProtocol: AnyObject, Hashable {
    associatedtype Label

    init(_ label: Label, id: Int?)
    
    var id: Int! { get set }
    var label: Label { get set }
    var children: OrderedSet<Self> { get set }
    var parent: Self? { get set }
    func addChild(_ child: Self, position: Int?)
    func deleteChild(_ child: Self)
    func positionOfChild(_ child: Self) -> Int
    func transformationCost(operation: TreeOperation, other: Self?) -> Double
    func clone() -> Self
}

public extension TreeNodeProtocol {
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
