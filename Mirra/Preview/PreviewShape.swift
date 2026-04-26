import Foundation

enum PreviewShape: String, CaseIterable {
    case roundedRectangle
    case circle
    case rectangle

    var displayName: String {
        switch self {
        case .roundedRectangle: "Rounded"
        case .circle: "Circle"
        case .rectangle: "Rectangle"
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .roundedRectangle: 10
        case .circle: .infinity  // will be clamped to half the shortest side
        case .rectangle: 0
        }
    }
}
