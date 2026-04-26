import Foundation

enum ClickThroughMode: String, CaseIterable {
    case normal
    case clickThrough

    var displayName: String {
        switch self {
        case .normal: "Normal"
        case .clickThrough: "Click Through"
        }
    }
}
