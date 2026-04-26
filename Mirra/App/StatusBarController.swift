import AppKit
import SwiftUI

@MainActor
final class StatusBarController {
    private var statusItem: NSStatusItem?

    var isPreviewEnabled: Bool = false
    var isMirrorEnabled: Bool = true
    var selectedQuality: CameraQuality = .medium
    var selectedCameraID: String?
    var availableCameras: [CameraDevice] = []
    var selectedPlacement: PreviewPlacement = .bottomTrailing
    var selectedSizePreset: PreviewSizePreset = .medium
    var isLaunchAtLogin: Bool = false
    var cameraState: CameraState = .idle

    var onTogglePreview: (() -> Void)?
    var onSelectCamera: ((String) -> Void)?
    var onToggleMirror: ((Bool) -> Void)?
    var onSelectQuality: ((CameraQuality) -> Void)?
    var onSelectPlacement: ((PreviewPlacement) -> Void)?
    var onSelectSizePreset: ((PreviewSizePreset) -> Void)?
    var onToggleLaunchAtLogin: ((Bool) -> Void)?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            let image = NSImage(named: "MenuBarIcon")
            image?.isTemplate = true
            button.image = image
        }

        updateMenu()
    }

    func updateMenu() {
        let menu = NSMenu()

        if cameraState == .unauthorized {
            let permItem = NSMenuItem(title: "Camera Access Required", action: nil, keyEquivalent: "")
            permItem.isEnabled = false
            menu.addItem(permItem)

            let openSettings = NSMenuItem(title: "Open System Settings…", action: #selector(openCameraSettings), keyEquivalent: "")
            openSettings.target = self
            menu.addItem(openSettings)
        } else {
            // Toggle preview
            let toggleTitle = isPreviewEnabled ? "Hide Preview" : "Show Preview"
            let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(togglePreview), keyEquivalent: "M")
            toggleItem.keyEquivalentModifierMask = [.command, .shift]
            toggleItem.target = self
            menu.addItem(toggleItem)

            menu.addItem(.separator())

            // Camera picker
            if availableCameras.isEmpty {
                let noCamera = NSMenuItem(title: "No Cameras Available", action: nil, keyEquivalent: "")
                noCamera.isEnabled = false
                menu.addItem(noCamera)
            } else {
                let cameraHeader = NSMenuItem(title: "Camera", action: nil, keyEquivalent: "")
                cameraHeader.isEnabled = false
                menu.addItem(cameraHeader)

                for camera in availableCameras {
                    let item = NSMenuItem(title: camera.name, action: #selector(selectCamera(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = camera.id
                    item.state = camera.id == selectedCameraID ? .on : .off
                    item.indentationLevel = 1
                    menu.addItem(item)
                }
            }

            menu.addItem(.separator())

            // Mirror toggle
            let mirrorItem = NSMenuItem(title: "Mirror", action: #selector(toggleMirror), keyEquivalent: "")
            mirrorItem.target = self
            mirrorItem.state = isMirrorEnabled ? .on : .off
            menu.addItem(mirrorItem)

            menu.addItem(.separator())

            // Quality submenu
            let qualityItem = NSMenuItem(title: "Quality", action: nil, keyEquivalent: "")
            let qualityMenu = NSMenu()
            for quality in CameraQuality.allCases {
                let item = NSMenuItem(title: quality.displayName, action: #selector(selectQuality(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = quality.rawValue
                item.state = quality == selectedQuality ? .on : .off
                qualityMenu.addItem(item)
            }
            qualityItem.submenu = qualityMenu
            menu.addItem(qualityItem)

            // Size submenu
            let sizeItem = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
            let sizeMenu = NSMenu()
            for preset in PreviewSizePreset.allCases {
                let item = NSMenuItem(title: preset.displayName, action: #selector(selectSizePreset(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = preset.rawValue
                item.state = preset == selectedSizePreset ? .on : .off
                sizeMenu.addItem(item)
            }
            sizeItem.submenu = sizeMenu
            menu.addItem(sizeItem)

            // Position submenu
            let posItem = NSMenuItem(title: "Position", action: nil, keyEquivalent: "")
            let posMenu = NSMenu()
            for placement in PreviewPlacement.allCases {
                let item = NSMenuItem(title: placement.displayName, action: #selector(selectPlacement(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = placement.rawValue
                item.state = placement == selectedPlacement ? .on : .off
                posMenu.addItem(item)
            }
            posItem.submenu = posMenu
            menu.addItem(posItem)
        }

        menu.addItem(.separator())

        // Launch at login
        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = isLaunchAtLogin ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Mirra", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    func updateIcon(previewActive: Bool) {
        let name = previewActive ? "MenuBarIconActive" : "MenuBarIcon"
        let image = NSImage(named: name)
        image?.isTemplate = true
        statusItem?.button?.image = image
    }

    // MARK: - Actions

    @objc private func togglePreview() {
        onTogglePreview?()
    }

    @objc private func selectCamera(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        onSelectCamera?(id)
    }

    @objc private func toggleMirror() {
        onToggleMirror?(!isMirrorEnabled)
    }

    @objc private func selectQuality(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let quality = CameraQuality(rawValue: raw) else { return }
        onSelectQuality?(quality)
    }

    @objc private func selectSizePreset(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let preset = PreviewSizePreset(rawValue: raw) else { return }
        onSelectSizePreset?(preset)
    }

    @objc private func selectPlacement(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let placement = PreviewPlacement(rawValue: raw) else { return }
        onSelectPlacement?(placement)
    }

    @objc private func toggleLaunchAtLogin() {
        onToggleLaunchAtLogin?(!isLaunchAtLogin)
    }

    @objc private func openCameraSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }
}
