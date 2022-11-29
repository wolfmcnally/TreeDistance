import Foundation
import WolfBase

final class ReversibleMap<K: Hashable, V: Hashable> {
    var dict: [K: V]
    var inverse: [V: K]
    
    init() {
        dict = [:]
        inverse = [:]
    }
    
    convenience init<S>(_ elements: S) where S: Sequence, S.Element == (K, V) {
        self.init()
        for (k, v) in elements {
            dict[k] = v
            inverse[v] = k
        }
    }
    
    func put(_ k: K, _ v: V) {
        dict[k] = v
        inverse[v] = k
    }
    
    func remove(_ k: K) {
        guard let v = dict.removeValue(forKey: k) else {
            return
        }
        inverse.removeValue(forKey: v)
    }
    
    func put<S>(contentsOf m: S) where S: Sequence, S.Element == (key: K, value: V) {
        for (k, v) in m {
            put(k, v)
        }
    }
    
    func has(_ k: K) -> Bool {
        dict[k] != nil
    }
    
    func hasInverse(_ v: V) -> Bool {
        inverse[v] != nil
    }
    
    func get(_ k: K) -> V {
        dict[k]!
    }
    
    func getInverse(_ v: V) -> K {
        inverse[v]!
    }
}

extension ReversibleMap: Sequence {
    typealias Element = (key: K, value: V)
    typealias Iterator = Dictionary<K, V>.Iterator

    func makeIterator() -> Iterator {
        dict.makeIterator()
    }
}

extension ReversibleMap: CustomStringConvertible where V: Comparable {
    var description: String {
        sorted(by: { $0.1 < $1.1 }).map({ "\($0.key): \($0.value)" }).joined(separator: ", ").flanked("[", "]")
    }
}

extension ReversibleMap: ExpressibleByDictionaryLiteral {
    convenience init(dictionaryLiteral elements: (K, V)...) {
        self.init(elements)
    }
}
