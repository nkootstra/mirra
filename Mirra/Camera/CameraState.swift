import Foundation

enum CameraState: Equatable, Sendable {
    case idle
    case unauthorized
    case noCameraAvailable
    case cameraInUse
    case cameraSuspended
    case disconnected
    case ready
    case previewing
}
