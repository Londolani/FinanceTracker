import Foundation

struct GoalItem: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var target: Double
    var saved: Double
    var isTracked: Bool
    var linkedAccountId: String?
    
    var progress: Double {
        guard target > 0 else { return 0 }
        return min(saved / target, 1.0)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: GoalItem, rhs: GoalItem) -> Bool {
        return lhs.id == rhs.id
    }
}
