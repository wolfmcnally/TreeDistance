import Foundation
import WolfBase

public final class TreeDistance<Node: TreeNodeProtocol> {
    typealias PostorderMap = ReversibleMap<Node, Int>
    typealias SeqMap = ReversibleMap<Node, Int>
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
        
        // prepare sequence numbers
        for (node, n) in postorder1 {
            node.seq = n
        }
        let offset = postorder1.count
        for (node, n) in postorder2 {
            node.seq = n + offset
        }
        var _nextSeq = postorder1.count + postorder2.count
        var nextSeq: Int {
            defer { _nextSeq += 1}
            return _nextSeq
        }
        
        var matchedNodes: [Node: Node] = [:]
        var matchedSequenceNumbers: [Int: Int] = [:]
        
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
                    clone.seq = nextSeq
                    matchedNodes[current.first] = clone
                    matchedSequenceNumbers[current.first.seq] = clone.seq
                    
                    if let second = current.second {
                        edit = Edit(
                            cost: current.cost,
                            operation: .insert(
                                seq: clone.seq,
                                label: clone.label,
                                parentSeq: matchedNodes[second]!.seq,
                                position: current.first.parent!.positionOfChild(current.first),
                                childrenCount: current.second.children.count,
                                descendantSeqs: []
                            )
                        )
                    } else {
                        edit = Edit(
                            cost: current.cost,
                            operation: .insertRoot(
                                seq: clone.seq,
                                label: clone.label
                            )
                        )
                    }
                case .delete:
                    edit = Edit(
                        cost: current.cost,
                        operation: .delete(
                            seq: current.first.seq
                        )
                    )
                case .rename:
                    edit = Edit(
                        cost: current.cost,
                        operation: .rename(
                            seq: current.first.seq,
                            label: current.second.label
                        )
                    )

                    matchedNodes[current.second] = current.first
                    matchedSequenceNumbers[current.second.seq] = current.first.seq
                }
                
                edits.append(edit)
                applyForestTrails(current.nextState)
                
                if case let .insert(seq, label, parentSeq, position, childrenCount, _) = edit.operation {
                    var descendentSeqs: [Int] = []
                    
                    f(current.first)
                    
                    func f(_ cur: Node) {
                        for child in cur.children {
                            if let descendant = matchedNodes[child] {
                                descendentSeqs.append(descendant.seq)
                            }
                            
                            f(child)
                        }
                    }

                    edit.operation = .insert(
                        seq: seq,
                        label: label,
                        parentSeq: parentSeq,
                        position: position,
                        childrenCount: childrenCount,
                        descendantSeqs: descendentSeqs
                    )
                }
            }
        }
    }
    
    public static func transformTree(_ root: Node, edits: [Edit]) -> Node {
        var resultRoot = root
        
        let seqNumbers = sequenceNumbers(root)
        
        for edit in edits {
            switch edit.operation {
            case .insert(let seq, let label, let parentSeq, let position, let childrenCount, let descendantSeqs):
                // insert a child and make demoted siblings its new children
                let existingNode = seqNumbers.getInverse(parentSeq)
                let inserted = Node(label, seq: seq)
                let parent = existingNode
                
                var toRemove: [Node] = []
                for child in parent.children {
                    for descSeq in descendantSeqs {
                        if descSeq == child.seq {
                            toRemove.append(child)
                            inserted.addChild(child: child, position: inserted.children.count)
                            child.parent = inserted
                        }
                    }
                }
                
                for child in toRemove {
                    parent.deleteChild(child)
                }
                
                let index = max(0, parent.children.count - childrenCount + 1 + position)
                parent.addChild(child: inserted, position: index)
                inserted.parent = parent
                seqNumbers.put(inserted, inserted.seq)
            case .insertRoot(let seq, let label):
                // insert a new root node
                let inserted = Node(label, seq: seq)
                inserted.addChild(child: resultRoot, position: 0)
                resultRoot.parent = inserted
                resultRoot = inserted
                seqNumbers.put(inserted, inserted.seq)
            case .delete(let seq):
                // delete node from the tree, promoting its children
                let deletedNode = seqNumbers.getInverse(seq)
                let position = deletedNode.parent!.positionOfChild(deletedNode)
                
                for i in (0..<deletedNode.children.count).reversed() {
                    deletedNode.parent!.addChild(child: deletedNode.children[i], position: position)
                    deletedNode.children[i].parent = deletedNode.parent!
                }
                
                deletedNode.parent!.deleteChild(deletedNode)
                seqNumbers.removeInverse(seq)
            case .rename(let seq, let label):
                let node = seqNumbers.getInverse(seq)
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
    
    static func sequenceNumbers(_ node: Node) -> SeqMap {
        let result = SeqMap()
        
        f(node)
        
        func f(_ current: Node) {
            for child in current.children {
                f(child)
            }
            result.put(current, current.seq)
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
            case delete(seq: Int)
            case rename(seq: Int, label: Label)
            case insertRoot(seq: Int, label: Label)
            case insert(seq: Int, label: Label, parentSeq: Int, position: Int, childrenCount: Int, descendantSeqs: [Int])
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
