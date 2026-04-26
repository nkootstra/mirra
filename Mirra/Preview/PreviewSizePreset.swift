import Foundation

enum PreviewSizePreset: String, CaseIterable, Identifiable, Sendable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }

    var size: CGSize {
        switch self {
        case .small: CGSize(width: 160, height: 120)
        case .medium: CGSize(width: 240, height: 180)
        case .large: CGSize(width: 320, height: 240)
        }
    }
}
