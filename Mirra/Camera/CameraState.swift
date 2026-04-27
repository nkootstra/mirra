import Foundation

enum CameraState: Equatable, Sendable {
    case idle
    case unauthorized
    case noCameraAvailable
    case cameraInUse
    case cameraSuspended
    case disconnected
    case ready
    case paused       // session alive but window hidden — instant resume
    case previewing
}
