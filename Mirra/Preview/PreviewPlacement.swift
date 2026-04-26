import Foundation

enum PreviewPlacement: String, CaseIterable, Identifiable, Sendable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
    case center

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .topLeading: "Top Left"
        case .topTrailing: "Top Right"
        case .bottomLeading: "Bottom Left"
        case .bottomTrailing: "Bottom Right"
        case .center: "Center"
        }
    }

    func origin(for windowSize: CGSize, in screenFrame: CGRect, padding: CGFloat = 20) -> CGPoint {
        switch self {
        case .topLeading:
            return CGPoint(
                x: screenFrame.minX + padding,
                y: screenFrame.maxY - windowSize.height - padding
            )
        case .topTrailing:
            return CGPoint(
                x: screenFrame.maxX - windowSize.width - padding,
                y: screenFrame.maxY - windowSize.height - padding
            )
        case .bottomLeading:
            return CGPoint(
                x: screenFrame.minX + padding,
                y: screenFrame.minY + padding
            )
        case .bottomTrailing:
            return CGPoint(
                x: screenFrame.maxX - windowSize.width - padding,
                y: screenFrame.minY + padding
            )
        case .center:
            return CGPoint(
                x: screenFrame.midX - windowSize.width / 2,
                y: screenFrame.midY - windowSize.height / 2
            )
        }
    }
}
