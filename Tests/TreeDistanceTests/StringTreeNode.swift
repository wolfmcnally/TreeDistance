import TreeDistance

public typealias StringTreeNode = TreeNode<String>

extension StringTreeNode: CustomStringConvertible {
    public var description: String {
        label
    }
}

extension StringTreeNode {
    public var treeString: String {
        var s = label
        if !children.isEmpty {
            s.append(children.map { $0.treeString }.joined(separator: ",").flanked("(", ")"))
        }
        return s
    }
}

public extension StringTreeNode {
    static func fromString(tree: String) -> StringTreeNode {
        var tree = ArraySlice(tree)
        
        @discardableResult
        func f(parent: StringTreeNode?) -> StringTreeNode? {
            var node = ""
            while !tree.isEmpty {
                let c = tree.first!
                tree = tree.dropFirst()
                
                if c == "(" {
                    let cur = StringTreeNode(node)
                    node = ""
                    f(parent: cur)
                    
                    if let parent {
                        parent.addChild(child: cur)
                        cur.parent = parent
                    } else {
                        return cur
                    }
                } else if c == "," || c == ")" {
                    if node != "" {
                        let cur = StringTreeNode(node)
                        node = ""
                        parent!.addChild(child: cur)
                        cur.parent = parent
                    }
                    
                    if c == ")" {
                        break
                    }
                } else {
                    node = String(c)
                }
            }
            
            if node != "" {
                return StringTreeNode(node)
            }
            
            return nil
        }
        
        return f(parent: nil)!
    }
}

public extension StringTreeNode {
    private static let alphabet = (0..<26).map { String(UnicodeScalar(Character("a").asciiValue! + $0)) }

    convenience init(maxDepth: Int, maxChildren: Int) {
        var rng = SystemRandomNumberGenerator()
        self.init(maxDepth: maxDepth, maxChildren: maxChildren, using: &rng)
    }
    
    convenience init<R: RandomNumberGenerator>(maxDepth: Int, maxChildren: Int, using rng: inout R) {
        func nextLabel() -> String {
            Self.alphabet.randomElement(using: &rng)!
        }

        func f(_ current: StringTreeNode, depth: Int) {
            guard depth <= maxDepth else {
                return
            }
            
            let nChildren = Int.random(in: 0 ..< maxChildren)
            for _ in 0 ..< nChildren {
                let child = Self(nextLabel())
                current.addChild(child: child)
                child.parent = current
                f(child, depth: depth + 1)
            }
        }

        self.init(nextLabel())
        f(self, depth: 1)
    }
}

extension String: TransformableLabel {
    public func transformationCost(operation: TreeOperation, other: String?) -> Double {
        switch operation {
        case .rename:
            return self == other! ? 0 : 1
        case .insert:
            return 1
        case .delete:
            return 1
        }
    }
}
