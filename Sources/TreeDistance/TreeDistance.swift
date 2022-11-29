import Foundation
import WolfBase

public final class TreeDistance<Node: TreeNodeProtocol> {
    typealias PostorderMap = ReversibleMap<Node, Int>
    
    public static func treeDistance(_ t1: Node, _ t2: Node) -> (cost: Double, edits: [Edit]) {
        var edits: [Edit] = []
        
        // prepare postorder numbering
        let postorder1 = postorderIdentifiers(t1)
        let postorder2 = postorderIdentifiers(t2)
        
        // prepare leftmost leaf descendants
        let lmld1 = leftmostLeafDescendants(t1, postorderIDs: postorder1)
        let lmld2 = leftmostLeafDescendants(t2, postorderIDs: postorder2)

        // prepare keyroots
        let keyRoots1 = keyroots(t1, postorderIDs: postorder1)
        let keyRoots2 = keyroots(t2, postorderIDs: postorder2)
        
        // prepare tree distance table and transformation list
        let tree1MaxIndex = postorder1.get(t1)
        let tree2MaxIndex = postorder2.get(t2)
        let tree1NodesCount = tree1MaxIndex + 1
        let tree2NodesCount = tree2MaxIndex + 1
        var treeDistance: [[ForestTrail?]] = Array(repeating: Array(repeating: nil, count: tree1NodesCount), count: tree2NodesCount)
        
        var matchedNodes: [Node: Node] = [:]

        // calculate tree distance
        for keyRoot1 in keyRoots1 {
            for keyRoot2 in keyRoots2 {
                forestDistance(keyRoot1, keyRoot2)
            }
        }
        
        applyForestTrails(treeDistance[tree2MaxIndex][tree1MaxIndex]!)
        edits.sort()
        
        let cost = treeDistance[tree2MaxIndex][tree1MaxIndex]!.totalCost
        
        return (cost, edits)

        func forestDistance(_ keyRoot1: Node, _ keyRoot2: Node) {
            let kr1 = postorder1.get(keyRoot1)
            let kr2 = postorder2.get(keyRoot2)
            
            let lm1 = postorder1.get(lmld1[kr1])
            let lm2 = postorder2.get(lmld2[kr2])
            
            let bound1 = kr1 - lm1 + 2
            let bound2 = kr2 - lm2 + 2
            
            // initialize forest distance table
            var forestDistance: [[ForestTrail?]] = Array(repeating: Array(repeating: nil, count: bound1), count: bound2)
            forestDistance[0][0] = ForestTrail()
            
            for (i, k) in zip(1..<bound2, lm2...) {
                let t = postorder2.getInverse(k)
                let ft = ForestTrail(operation: .insert, first: t, second: t.parent)
                ft.nextState = forestDistance[i - 1][0]!
                forestDistance[i][0] = ft
            }
            
            for (j, l) in zip(1..<bound1, lm1...) {
                let t = postorder1.getInverse(l)
                let ft = ForestTrail(operation: .delete, first: t)
                ft.nextState = forestDistance[0][j - 1]!
                forestDistance[0][j] = ft
                
                // prevent removing the root node
                if t.parent == nil {
                    forestDistance[0][j]!.cost = .infinity
                }
            }
            
            // fill in the rest of forest distances
            for (k, j) in zip(lm1...kr1, 1...) {
                for(l, i) in zip(lm2...kr2, 1...) {
                    let first = postorder1.getInverse(k)
                    let second = postorder2.getInverse(l)
                    
                    let insert = ForestTrail(operation: .insert, first: second, second: second.parent)
                    insert.nextState = forestDistance[i - 1][j]!
                    
                    let delete = ForestTrail(operation: .delete, first: first)
                    delete.nextState = forestDistance[i][j - 1]!
                    
                    // prevent removing the root node
                    if first.parent == nil {
                        delete.cost = .infinity
                    }
                    
                    // both key roots present a tree?
                    let rename: ForestTrail
                    let trees = postorder1.get(lmld1[k]) == lm1 && postorder2.get(lmld2[l]) == lm2
                    if trees {
                        rename = ForestTrail(operation: .rename, first: first, second: second)
                        rename.nextState = forestDistance[i - 1][j - 1]!
                    } else {
                        rename = ForestTrail(treeState: treeDistance[l][k]!, first: first, second: second)
                        rename.nextState = forestDistance[postorder2.get(lmld2[l]) - lm2][postorder1.get(lmld1[k]) - lm1]!
                    }
                    
                    let min = [(insert, insert.totalCost), (delete, delete.totalCost), (rename, rename.totalCost)].min(by: { $0.1 < $1.1 })!
                    forestDistance[i][j] = min.0
                    
                    if trees {
                        treeDistance[l][k] = forestDistance[i][j]
                    }
                }
            }
        }
        
        func applyForestTrails(_ current: ForestTrail) {
            guard let nextState = current.nextState else {
                return
            }
            
            if let treeState = current.treeState {
                applyForestTrails(nextState)
                applyForestTrails(treeState)
            } else {
                let edit: Edit
                switch current.operation! {
                case .insert:
                    let clone = current.first.clone()
                    matchedNodes[current.first] = clone
                    
                    if let second = current.second {
                        edit = Edit(operation: .insert, cost: current.cost, firstNode: clone, secondNode: matchedNodes[second])
                        edit.position = current.first.parent!.positionOfChild(current.first)
                        edit.childrenCount = current.second.children.count
                    } else {
                        edit = Edit(operation: .insert, cost: current.cost, firstNode: clone)
                    }
                case .delete:
                    edit = Edit(operation: .delete, cost: current.cost, firstNode: current.first)
                case .rename:
                    edit = Edit(operation: .rename, cost: current.cost, firstNode: current.first, secondNode: current.second)
                    matchedNodes[current.second] = current.first
                }
                
                edits.append(edit)
                applyForestTrails(current.nextState)
                
                if current.operation == .insert {
                    var descendents: [Node] = []
                    
                    f(current.first)
                    
                    func f(_ cur: Node) {
                        for child in cur.children {
                            if let descendant = matchedNodes[child] {
                                descendents.append(descendant)
                            }
                            
                            f(child)
                        }
                    }
                    
                    edit.descendants = descendents
                }
            }
        }
    }
    
    public static func transformTree(_ root: Node, edits: [Edit]) -> Node {
        var root = root
        
        for edit in edits {
            switch edit.operation {
            case .insert:
                if let secondNode = edit.secondNode {
                    // insert a child and make demoted siblings its new children
                    let parent = secondNode
                    let inserted = edit.firstNode
                    
                    var toRemove: [Node] = []
                    for child in parent.children {
                        for desc in edit.descendants {
                            if desc === child {
                                toRemove.append(child)
                                inserted.addChild(child: child, position: inserted.children.count)
                                child.parent = inserted
                            }
                        }
                    }
                    
                    for child in toRemove {
                        parent.deleteChild(child)
                    }
                    
                    let index = max(0, parent.children.count - edit.childrenCount + 1 + edit.position)
                    parent.addChild(child: inserted, position: index)
                    inserted.parent = parent
                } else {
                    // insert a new root node
                    let inserted = edit.firstNode
                    inserted.addChild(child: root, position: 0)
                    root.parent = inserted
                    root = inserted
                }
                
            case .delete:
                // delete node from the tree, promoting its children
                let deleted = edit.firstNode
                let position = deleted.parent!.positionOfChild(deleted)
                
                for i in (0..<deleted.children.count).reversed() {
                    deleted.parent!.addChild(child: deleted.children[i], position: position)
                    deleted.children[i].parent = deleted.parent!
                }
                
                deleted.parent!.deleteChild(deleted)
                
            case .rename:
                let first = edit.firstNode
                let second = edit.secondNode!
                first.label = second.label
            }
        }
        
        return root
    }
    
    class ForestTrail: CustomStringConvertible {
        var operation: TreeOperation! = nil
        var cost: Double = 0
        var nextState: ForestTrail! = nil
        var treeState: ForestTrail! = nil
        var first: Node! = nil
        var second: Node! = nil
        
        init() {
            self.cost = 0
        }
        
        init(operation: TreeOperation, first: Node, second: Node? = nil) {
            self.operation = operation
            self.first = first
            self.second = second
            self.cost = first.transformationCost(operation: operation, other: second)
        }
        
        init(treeState: ForestTrail, first: Node, second: Node) {
            self.operation = .rename
            self.first = first
            self.second = second
            self.cost = treeState.totalCost
            self.treeState = treeState
        }
        
        var totalCost: Double {
            if let nextState {
                return cost + nextState.totalCost
            } else {
                return cost
            }
        }
        
        var description: String {
            var comps: [String] = []
            if let operation { comps.append(operation†) }
            comps.append("cost: \(Int(cost))")
            if let first { comps.append("first: \(first)") }
            if let second { comps.append("second: \(second)") }
            if let nextState { comps.append("nextState: \(nextState)")}
            if let treeState { comps.append("treeState: \(treeState)")}
            return comps.joined(separator: ", ").flanked("(", ")")
        }
    }
                                                                
    public class Edit: Comparable, CustomStringConvertible {
        let operation: TreeOperation
        let firstNode: Node
        let secondNode: Node!
        var position: Int! = nil
        var descendants: [Node]! = nil
        var childrenCount: Int! = nil
        let cost: Double
        
        init(operation: TreeOperation, cost: Double, firstNode: Node, secondNode: Node? = nil) {
            self.operation = operation
            self.cost = cost
            self.firstNode = firstNode
            self.secondNode = secondNode
        }

        public static func == (lhs: Edit, rhs: Edit) -> Bool {
            lhs.operation == rhs.operation
        }
        
        public static func < (lhs: Edit, rhs: Edit) -> Bool {
            lhs.operation < rhs.operation
        }
        
        public var description: String {
            var comps: [String] = []
            comps.append(operation†)
            comps.append("firstNode: \(firstNode†)")
            if let secondNode {
                comps.append("secondNode: \(secondNode†)")
            }
            comps.append("cost: \(cost)")
            if operation == .insert {
                comps.append("position: \(position†)")
                comps.append("descendants: \(descendants†)")
                comps.append("childrenCount: \(childrenCount†)")
            }
            return comps.joined(separator: ", ").flanked("(", ")")
        }
    }
    
    static func postorderIdentifiers(_ node: Node) -> PostorderMap {
        var nextID = 0
        let result = PostorderMap()

        f(node)

        func f(_ current: Node) {
            for child in current.children {
                f(child)
            }
            result.put(current, nextID)
            nextID += 1
        }
        
        return result
    }
    
    static func leftmostLeafDescendants(_ root: Node, postorderIDs: PostorderMap) -> [Node] {
        var result: [Node?] = Array(repeating: nil, count: postorderIDs.get(root) + 1)
        
        f(root, chain: [])
        
        func f(_ current: Node, chain: [Node]) {
            if current.children.isEmpty {
                // leftmost descendant of a leaf is the leaf itself
                result[postorderIDs.get(current)] = current
                
                // assign the rest of nodes in the chain the same leftmost leaf descendant - this leaf
                for ancestor in chain {
                    result[postorderIDs.get(ancestor)] = current
                }
            } else {
                for (index, child) in current.children.enumerated() {
                    f(child, chain: index == 0 ? chain.appending(current) : [])
                }
            }
        }
        
        return result.map { $0! }
    }
    
    static func keyroots(_ root: Node, postorderIDs: PostorderMap) -> [Node] {
        var result: [Node] = []
        
        f(root, chain: [])
        
        func f(_ current: Node, chain: [Node]) {
            if current.children.isEmpty {
                if chain.isEmpty {
                    result.append(current)
                } else {
                    // the first node in the chain is the keyroot node
                    result.append(chain.first!)
                }
            } else {
                for (index, child) in current.children.enumerated() {
                    f(child, chain: index == 0 ? chain.appending(current) : [])
                }
            }
        }
        
        return result.sorted { postorderIDs.get($0) < postorderIDs.get($1) }
    }
}
