import SwiftUI

struct PermissionRecoveryView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.badge.exclamationmark")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("Camera Access Required")
                .font(.headline)

            Text("Mirra needs camera access to show a live preview. Grant access in System Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(16)
        .frame(width: 200)
    }
}
