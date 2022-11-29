import XCTest
@testable import TreeDistance

final class ReversibleMapTests: XCTestCase {
    func testPut() {
        let map = ReversibleMap<String, Int>()
        map.put("a", 1)
        map.put("b", 2)
        map.put("c", 3)
        XCTAssertEqual(map.get("a"), 1)
        XCTAssertEqual(map.getInverse(2), "b")
        XCTAssertNotEqual(map.getInverse(3), "h")
    }
    
    func testRemove() {
        let map = ReversibleMap<String, Int>()
        map.put("a", 1)
        map.put("b", 2)
        map.put("c", 3)
        map.remove("a")
        XCTAssertFalse(map.hasInverse(1))
        XCTAssertEqual(map.getInverse(2), "b")
    }
    
    func testPutAll() {
        let map1 = ReversibleMap<String, Int>()
        map1.put("a", 1)
        map1.put("b", 2)
        map1.put("c", 3)

        let map2 = ReversibleMap<String, Int>()
        map2.put(contentsOf: map1)
        XCTAssertEqual(map2.get("a"), 1)
        XCTAssertEqual(map2.getInverse(2), "b")
        XCTAssertNotEqual(map2.getInverse(3), "h")
    }
}
