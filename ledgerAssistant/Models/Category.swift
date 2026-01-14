import SwiftUI

enum LedgerCategory: String, CaseIterable, Identifiable {
    case food = "食"
    case clothing = "衣"
    case housing = "住"
    case transportation = "行"
    case entertainment = "娛"
    case recreation = "樂"
    case other = "其它"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .clothing: return "tshirt.fill"
        case .housing: return "house.fill"
        case .transportation: return "car.fill"
        case .entertainment: return "gamecontroller.fill"
        case .recreation: return "music.note"
        case .other: return "ellipsis.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .food: return .orange
        case .clothing: return .blue
        case .housing: return .green
        case .transportation: return .gray
        case .entertainment: return .purple
        case .recreation: return .pink
        case .other: return .secondary
        }
    }
}
