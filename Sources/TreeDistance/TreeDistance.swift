import Foundation
import WolfBase

public final class TreeDistance<Node: TreeNodeProtocol> {
    typealias PostorderMap = ReversibleMap<Node, Int>
    typealias IDMap = ReversibleMap<Node, Int>
    public typealias Label = Node.Label
    
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
        
        // prepare ID numbers
        for (node, id) in postorder1 {
            node.id = id
        }
        let offset = postorder1.count
        for (node, id) in postorder2 {
            node.id = id + offset
        }
        var _nextID = postorder1.count + postorder2.count
        var nextID: Int {
            defer { _nextID += 1}
            return _nextID
        }
        
        var matchedNodes: [Node: Node] = [:]
        var matchedIDs: [Int: Int] = [:]
        
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
                    let cloneID = nextID
                    clone.id = cloneID
                    matchedNodes[current.first] = clone
                    matchedIDs[current.first.id] = cloneID
                    
                    if let second = current.second {
                        edit = Edit(
                            cost: current.cost,
                            operation: .insert(
                                id: cloneID,
                                label: clone.label,
                                parentID: matchedNodes[second]!.id,
                                position: current.first.parent!.positionOfChild(current.first),
                                childrenCount: current.second.children.count,
                                descendantIDs: []
                            )
                        )
                    } else {
                        edit = Edit(
                            cost: current.cost,
                            operation: .insertRoot(
                                id: cloneID,
                                label: clone.label
                            )
                        )
                    }
                case .delete:
                    edit = Edit(
                        cost: current.cost,
                        operation: .delete(
                            id: current.first.id
                        )
                    )
                case .rename:
                    edit = Edit(
                        cost: current.cost,
                        operation: .rename(
                            id: current.first.id,
                            label: current.second.label
                        )
                    )

                    matchedNodes[current.second] = current.first
                    matchedIDs[current.second.id] = current.first.id
                }
                
                edits.append(edit)
                applyForestTrails(current.nextState)
                
                if case let .insert(id, label, parentID, position, childrenCount, _) = edit.operation {
                    var descendentIDs: [Int] = []
                    
                    f(current.first)
                    
                    func f(_ cur: Node) {
                        for child in cur.children {
                            if let descendant = matchedNodes[child] {
                                descendentIDs.append(descendant.id)
                            }
                            
                            f(child)
                        }
                    }

                    edit.operation = .insert(
                        id: id,
                        label: label,
                        parentID: parentID,
                        position: position,
                        childrenCount: childrenCount,
                        descendantIDs: descendentIDs
                    )
                }
            }
        }
    }
    
    public static func transformTree(_ root: Node, edits: [Edit]) -> Node {
        var resultRoot = root
        
        let ids = postorderIdentifiers(root)
        
        for edit in edits {
            switch edit.operation {
            case .insert(let id, let label, let parentID, let position, let childrenCount, let descendantIDs):
                // insert a child and make demoted siblings its new children
                let existingNode = ids.getInverse(parentID)
                let inserted = Node(label, id: id)
                let parent = existingNode
                
                var toRemove: [Node] = []
                for child in parent.children {
                    let childID = ids.get(child)
                    for descID in descendantIDs {
                        if descID == childID {
                            toRemove.append(child)
                            inserted.addChild(child, position: inserted.children.count)
                            child.parent = inserted
                        }
                    }
                }
                
                for child in toRemove {
                    parent.deleteChild(child)
                }
                
                let index = max(0, parent.children.count - childrenCount + 1 + position)
                parent.addChild(inserted, position: index)
                inserted.parent = parent
                ids.put(inserted, id)
            case .insertRoot(let id, let label):
                // insert a new root node
                let inserted = Node(label, id: id)
                inserted.addChild(resultRoot, position: 0)
                resultRoot.parent = inserted
                resultRoot = inserted
                ids.put(inserted, id)
            case .delete(let id):
                // delete node from the tree, promoting its children
                let deletedNode = ids.getInverse(id)
                let position = deletedNode.parent!.positionOfChild(deletedNode)
                
                for i in (0..<deletedNode.children.count).reversed() {
                    deletedNode.parent!.addChild(deletedNode.children[i], position: position)
                    deletedNode.children[i].parent = deletedNode.parent!
                }
                
                deletedNode.parent!.deleteChild(deletedNode)
                ids.removeInverse(id)
            case .rename(let id, let label):
                let node = ids.getInverse(id)
                node.label = label
            }
        }
        
        return resultRoot
    }
}

extension TreeDistance {
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

extension TreeDistance {
    public class Edit: Comparable {
        public let cost: Double
        public var operation: Operation
        
        public enum Operation {
            case delete(id: Int)
            case rename(id: Int, label: Label)
            case insertRoot(id: Int, label: Label)
            case insert(id: Int, label: Label, parentID: Int, position: Int, childrenCount: Int, descendantIDs: [Int])
        }
        
        init(cost: Double, operation: Operation) {
            self.cost = cost
            self.operation = operation
        }
        
        var ordinal: Int {
            switch operation {
            case .delete:
                return 0
            case .rename:
                return 1
            case .insert, .insertRoot:
                return 2
            }
        }
        
        public static func == (lhs: Edit, rhs: Edit) -> Bool {
            lhs.ordinal == rhs.ordinal
        }
        
        public static func < (lhs: Edit, rhs: Edit) -> Bool {
            lhs.ordinal < rhs.ordinal
        }
    }
}

extension TreeDistance.Edit: CustomStringConvertible {
    public var description: String {
        let comps = ["Edit(\(cost))", operation†]
        return comps.joined(separator: " ").flanked("(", ")")
    }
}
