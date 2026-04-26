import Foundation

enum HoverMode: String, CaseIterable {
    case none
    case fade
    case hide

    var displayName: String {
        switch self {
        case .none: "None"
        case .fade: "Fade"
        case .hide: "Hide"
        }
    }
}

enum HoverOpacity: String, CaseIterable {
    case ninety = "0.9"
    case seventy = "0.7"
    case fifty = "0.5"
    case thirty = "0.3"
    case ten = "0.1"

    var displayName: String {
        switch self {
        case .ninety: "90%"
        case .seventy: "70%"
        case .fifty: "50%"
        case .thirty: "30%"
        case .ten: "10%"
        }
    }

    var value: CGFloat {
        CGFloat(Double(rawValue) ?? 0.3)
    }
}
