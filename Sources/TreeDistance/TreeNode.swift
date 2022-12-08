import Foundation
import OrderedCollections

public final class TreeNode<Label: TransformableLabel>: TreeNodeProtocol {
    public var id: Int!
    public var label: Label
    public weak var parent: TreeNode? = nil
    public var children: OrderedSet<TreeNode> = []
    
    public init(_ label: Label, id: Int? = nil) {
        self.id = id
        self.label = label
    }
    
    public func addChild(_ child: TreeNode, position: Int? = nil) {
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

extension TreeNode: CustomStringConvertible {
    public var description: String {
        String(describing: label)
    }
}

public extension TreeNode {
    func format() -> String {
        var elements: [(Label, Int)] = []
        
        func f(_ current: TreeNode<Label>, _ level: Int) {
            elements.append((current.label, level))
            for child in current.children {
                f(child, level + 1)
            }
        }
        
        f(self, 0)
        
        return elements.map { "\(String(repeating: " ", count: $1 * 4))\($0)" }.joined(separator: "\n")
    }
}
