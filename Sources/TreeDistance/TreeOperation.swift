import Foundation

public enum TreeOperation: Int {
    case delete
    case rename
    case insert
}

extension TreeOperation: CustomStringConvertible {
    public var description: String {
        switch self {
        case .delete:
            return "delete"
        case .rename:
            return "rename"
        case .insert:
            return "insert"
        }
    }
}

extension TreeOperation: Comparable {
    public static func < (lhs: TreeOperation, rhs: TreeOperation) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
