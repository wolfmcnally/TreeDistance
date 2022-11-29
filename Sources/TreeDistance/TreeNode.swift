import Foundation
import OrderedCollections

public final class TreeNode<Label: TransformableLabel>: TreeNodeProtocol {
    public let uuid: UUID
    public var label: Label
    public var parent: TreeNode? = nil
    public var children: OrderedSet<TreeNode> = []
    
    public init(_ label: Label) {
        self.uuid = UUID()
        self.label = label
    }
    
    public func addChild(child: TreeNode, position: Int? = nil) {
        if let position {
            children.insert(child, at: position)
        } else {
            children.append(child)
        }
    }
    
    public func deleteChild(_ child: TreeNode) {
        children.remove(at: positionOfChild(child))
    }
    
    public func positionOfChild(_ child: TreeNode) -> Int {
        children.firstIndex(of: child)!
    }

    public func clone() -> Self {
        Self(self.label)
    }

    public static func == (lhs: TreeNode<Label>, rhs: TreeNode<Label>) -> Bool {
        lhs === rhs
    }

    public func transformationCost(operation: TreeOperation, other: TreeNode?) -> Double {
        label.transformationCost(operation: operation, other: other?.label)
    }
}
