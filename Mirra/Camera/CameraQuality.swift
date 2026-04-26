import AVFoundation

enum CameraQuality: String, CaseIterable, Identifiable, Sendable {
    case low
    case medium
    case best

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .best: "Best"
        }
    }

    var capturePreset: AVCaptureSession.Preset {
        switch self {
        case .low: .low
        case .medium: .medium
        case .best: .high
        }
    }
}
