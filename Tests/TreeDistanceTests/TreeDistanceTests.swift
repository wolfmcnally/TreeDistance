import XCTest
import WolfBase
@testable import TreeDistance

final class TreeDistanceTests: XCTestCase {
    func testStringTrees() {
        var rng = makeRNG()
        for _ in 0 ..< 100 {
            let tree1 = StringTreeNode(maxDepth: 5, maxChildren: 5, using: &rng).treeString
            let tree2 = StringTreeNode.fromString(tree: tree1).treeString
            XCTAssertEqual(tree1, tree2)
        }
    }
    
    func testBasics() {
        let treeString = "A(B(C,D,E(F)),G)"
        let root = StringTreeNode.fromString(tree: treeString)
        XCTAssertEqual(root.treeString, treeString)

        let postorderIDs = TreeDistance.postorderIdentifiers(root)
        XCTAssertEqual(postorderIDs†, "[C: 0, D: 1, F: 2, E: 3, B: 4, G: 5, A: 6]")

        let lmlds = TreeDistance.leftmostLeafDescendants(root, postorderIDs: postorderIDs)
        XCTAssertEqual(lmlds†, "[C, D, F, F, C, G, C]")

        let keyroots = TreeDistance.keyroots(root, postorderIDs: postorderIDs)
        XCTAssertEqual(keyroots†, "[D, E, G, A]")
    }
    
    func testTreeDistance() {
        func run(_ a: String, _ b: String, _ expected: Double) {
            let t1 = StringTreeNode.fromString(tree: a)
            let t2 = StringTreeNode.fromString(tree: b)
            let cost = TreeDistance.treeDistance(t1, t2).cost
            XCTAssertEqual(cost, expected)
        }

        run("a(b)", "a(b)", 0)
        run("a(c)", "a(d)", 1)
        run("4(1,2,3)", "4(3(1,2))", 2)
        run("a(b,c)", "a(b,g)", 1)

        var rng = makeRNG()
        for _ in 0..<100 {
            let tree = StringTreeNode(maxDepth: 5, maxChildren: 4, using: &rng).treeString
            run(tree, tree, 0)
        }
    }
    
    func testTransformTree() {
        func run1(_ a: String, _ b: String) {
            let t1 = StringTreeNode.fromString(tree: a)
            let t2 = StringTreeNode.fromString(tree: b)
            let edits = TreeDistance.treeDistance(t1, t2).edits
            let c = TreeDistance.transformTree(t1, edits: edits).treeString
            XCTAssertEqual(c, b)
        }

        func run(_ a: String, _ b: String) {
            run1(a, b)
            run1(b, a)
        }
        
        run("4(1,2,3)", "5(3(1,2),4)")
        run("a(b(d,e),c(f,g))", "a(b(c(d,e,f)))")
        run("a(b(c,d),e(f(i,j),g,h(k)))", "a(b(c(d(e))))")
        run("a(b(c(d(e))))", "a(b(c,d),e(f(i,j),g,h(k)))")
        run("a(d)", "a(b,c,d)")
        run("f(d(a,c(b)),e)", "f(c(d(a,b)),e)")
        run("a(b)", "a(b)")
        run("a(b,b,c(c))", "d(a,a,a)")
        run("f(d(a,c(b)),e)", "f(c(d(a,b)),e)")

        var rng = makeRNG()
        for _ in 0..<100 {
            let tree1 = StringTreeNode(maxDepth: 3, maxChildren: 8, using: &rng).treeString
            let tree2 = StringTreeNode(maxDepth: 6, maxChildren: 2, using: &rng).treeString
            run(tree1, tree2)
        }
    }
    
    func makeRNG() -> some RandomNumberGenerator {
        let state: Xoroshiro256StarStar.State = (7943088474095033134, 2201563221578303974, 15451724982873067437, 14892261624674498107)
        return Xoroshiro256StarStar(state: state)
    }
}
