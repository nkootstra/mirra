import Foundation

enum BorderRadius: String, CaseIterable {
    case none = "0"
    case small = "6"
    case medium = "12"
    case large = "20"
    case extraLarge = "32"

    var displayName: String {
        switch self {
        case .none: "None"
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .extraLarge: "Extra Large"
        }
    }

    var value: CGFloat {
        CGFloat(Double(rawValue) ?? 12)
    }
}
