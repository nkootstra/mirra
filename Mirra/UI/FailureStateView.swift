import SwiftUI

struct FailureStateView: View {
    let state: CameraState

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 24))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.caption)
                .fontWeight(.medium)

            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    private var iconName: String {
        switch state {
        case .noCameraAvailable: "camera.badge.exclamationmark"
        case .cameraInUse: "camera.badge.clock"
        case .cameraSuspended: "pause.circle"
        case .disconnected: "cable.connector.slash"
        default: "exclamationmark.triangle"
        }
    }

    private var title: String {
        switch state {
        case .noCameraAvailable: "No Camera"
        case .cameraInUse: "Camera In Use"
        case .cameraSuspended: "Camera Paused"
        case .disconnected: "Camera Disconnected"
        default: "Camera Unavailable"
        }
    }

    private var message: String {
        switch state {
        case .noCameraAvailable: "Connect a camera to get started."
        case .cameraInUse: "Another app is using the camera."
        case .cameraSuspended: "The camera is temporarily paused."
        case .disconnected: "The camera was disconnected. It will recover automatically when reconnected."
        default: "An unexpected error occurred."
        }
    }
}
