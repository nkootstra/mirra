import SwiftUI

struct StatusMenuView: View {
    let isPreviewEnabled: Bool
    let isMirrorEnabled: Bool
    let selectedQuality: CameraQuality
    let selectedCameraID: String?
    let cameras: [CameraDevice]
    let cameraState: CameraState
    let selectedPlacement: PreviewPlacement
    let selectedSizePreset: PreviewSizePreset
    let isLaunchAtLogin: Bool

    let onTogglePreview: () -> Void
    let onSelectCamera: (String) -> Void
    let onToggleMirror: (Bool) -> Void
    let onSelectQuality: (CameraQuality) -> Void
    let onSelectPlacement: (PreviewPlacement) -> Void
    let onSelectSizePreset: (PreviewSizePreset) -> Void
    let onToggleLaunchAtLogin: (Bool) -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if cameraState == .unauthorized {
                PermissionRecoveryView()
                Divider().padding(.vertical, 4)
            } else {
                // Toggle preview
                Button(action: onTogglePreview) {
                    Label(
                        isPreviewEnabled ? "Hide Preview" : "Show Preview",
                        systemImage: isPreviewEnabled ? "eye.slash" : "eye"
                    )
                }
                .buttonStyle(MenuItemButtonStyle())

                Divider().padding(.vertical, 4)

                // Camera picker
                if cameras.isEmpty {
                    Text("No cameras available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                } else {
                    SectionHeader("Camera")

                    ForEach(cameras) { camera in
                        Button(action: { onSelectCamera(camera.id) }) {
                            CheckmarkRow(camera.name, isSelected: camera.id == selectedCameraID)
                        }
                        .buttonStyle(MenuItemButtonStyle())
                    }
                }

                Divider().padding(.vertical, 4)

                // Mirror toggle
                Button(action: { onToggleMirror(!isMirrorEnabled) }) {
                    CheckmarkRow("Mirror", isSelected: isMirrorEnabled)
                }
                .buttonStyle(MenuItemButtonStyle())

                Divider().padding(.vertical, 4)

                // Quality picker
                SectionHeader("Quality")
                ForEach(CameraQuality.allCases) { quality in
                    Button(action: { onSelectQuality(quality) }) {
                        CheckmarkRow(quality.displayName, isSelected: quality == selectedQuality)
                    }
                    .buttonStyle(MenuItemButtonStyle())
                }

                Divider().padding(.vertical, 4)

                // Size picker
                SectionHeader("Size")
                ForEach(PreviewSizePreset.allCases) { preset in
                    Button(action: { onSelectSizePreset(preset) }) {
                        CheckmarkRow(preset.displayName, isSelected: preset == selectedSizePreset)
                    }
                    .buttonStyle(MenuItemButtonStyle())
                }

                Divider().padding(.vertical, 4)

                // Placement picker
                SectionHeader("Position")
                ForEach(PreviewPlacement.allCases) { placement in
                    Button(action: { onSelectPlacement(placement) }) {
                        CheckmarkRow(placement.displayName, isSelected: placement == selectedPlacement)
                    }
                    .buttonStyle(MenuItemButtonStyle())
                }

                Divider().padding(.vertical, 4)
            }

            // Launch at login
            Button(action: { onToggleLaunchAtLogin(!isLaunchAtLogin) }) {
                CheckmarkRow("Launch at Login", isSelected: isLaunchAtLogin)
            }
            .buttonStyle(MenuItemButtonStyle())

            Divider().padding(.vertical, 4)

            Button(action: onQuit) {
                Label("Quit Mirra", systemImage: "power")
            }
            .buttonStyle(MenuItemButtonStyle())
        }
        .padding(.vertical, 8)
        .frame(width: 200)
        .focusEffectDisabled()
    }
}

// MARK: - Helpers

private struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
    }
}

private struct CheckmarkRow: View {
    let title: String
    let isSelected: Bool

    init(_ title: String, isSelected: Bool) {
        self.title = title
        self.isSelected = isSelected
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption)
            }
        }
    }
}

private struct MenuItemButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                configuration.isPressed
                    ? Color.accentColor.opacity(0.2)
                    : Color.clear
            )
            .cornerRadius(4)
            .padding(.horizontal, 4)
    }
}

extension View {
    @ViewBuilder
    func removeFocusRing() -> some View {
        self.focusEffectDisabled()
    }
}
