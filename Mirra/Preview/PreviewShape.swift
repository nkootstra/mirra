import Foundation

enum PreviewShape: String, CaseIterable {
    case circle
    case square
    case rectangle

    var displayName: String {
        switch self {
        case .circle: "Circle"
        case .square: "Square"
        case .rectangle: "Rectangle"
        }
    }

    /// Whether this shape forces equal width and height.
    var isSquare: Bool {
        switch self {
        case .circle, .square: true
        case .rectangle: false
        }
    }
}
