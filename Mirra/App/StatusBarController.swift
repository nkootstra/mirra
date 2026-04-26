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
    var selectedShape: PreviewShape = .rectangle
    var selectedBorderRadius: BorderRadius = .medium
    var selectedHoverMode: HoverMode = .fade
    var selectedHoverOpacity: HoverOpacity = .thirty
    var selectedScreenNumber: Int?  // nil = main screen
    var isLaunchAtLogin: Bool = false
    var cameraState: CameraState = .idle

    var onTogglePreview: (() -> Void)?
    var onSelectCamera: ((String) -> Void)?
    var onToggleMirror: ((Bool) -> Void)?
    var onSelectQuality: ((CameraQuality) -> Void)?
    var onSelectPlacement: ((PreviewPlacement) -> Void)?
    var onSelectSizePreset: ((PreviewSizePreset) -> Void)?
    var onSelectShape: ((PreviewShape) -> Void)?
    var onSelectBorderRadius: ((BorderRadius) -> Void)?
    var onSelectHoverMode: ((HoverMode) -> Void)?
    var onSelectHoverOpacity: ((HoverOpacity) -> Void)?
    var onSelectScreen: ((Int?) -> Void)?
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

            // Mirror toggle
            let mirrorItem = NSMenuItem(title: "Mirror", action: #selector(toggleMirror), keyEquivalent: "")
            mirrorItem.target = self
            mirrorItem.state = isMirrorEnabled ? .on : .off
            menu.addItem(mirrorItem)

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

            menu.addItem(.separator())

            // Appearance submenu
            let appearanceItem = NSMenuItem(title: "Appearance", action: nil, keyEquivalent: "")
            let appearanceMenu = NSMenu()

            // Shape
            let shapeItem = NSMenuItem(title: "Shape", action: nil, keyEquivalent: "")
            let shapeMenu = NSMenu()
            for shape in PreviewShape.allCases {
                let item = NSMenuItem(title: shape.displayName, action: #selector(selectShape(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = shape.rawValue
                item.state = shape == selectedShape ? .on : .off
                shapeMenu.addItem(item)
            }
            shapeItem.submenu = shapeMenu
            appearanceMenu.addItem(shapeItem)

            // Size
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
            appearanceMenu.addItem(sizeItem)

            // Border radius (disabled for circle)
            let radiusItem = NSMenuItem(title: "Border Radius", action: nil, keyEquivalent: "")
            if selectedShape == .circle {
                radiusItem.isEnabled = false
            } else {
                let radiusMenu = NSMenu()
                for radius in BorderRadius.allCases {
                    let item = NSMenuItem(title: radius.displayName, action: #selector(selectBorderRadius(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = radius.rawValue
                    item.state = radius == selectedBorderRadius ? .on : .off
                    radiusMenu.addItem(item)
                }
                radiusItem.submenu = radiusMenu
            }
            appearanceMenu.addItem(radiusItem)

            appearanceItem.submenu = appearanceMenu
            menu.addItem(appearanceItem)

            // Placement submenu
            let placementItem = NSMenuItem(title: "Placement", action: nil, keyEquivalent: "")
            let placementMenu = NSMenu()

            // Position
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
            placementMenu.addItem(posItem)

            // Display (only when multiple screens)
            let screens = NSScreen.screens
            if screens.count > 1 {
                let displayItem = NSMenuItem(title: "Display", action: nil, keyEquivalent: "")
                let displayMenu = NSMenu()

                for (index, screen) in screens.enumerated() {
                    let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? Int
                    let name = screen.localizedName
                    let label = index == 0 ? "\(name) (Main)" : name
                    let item = NSMenuItem(title: label, action: #selector(selectScreen(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = screenNumber
                    item.state = screenNumber == selectedScreenNumber ? .on : .off
                    displayMenu.addItem(item)
                }

                displayItem.submenu = displayMenu
                placementMenu.addItem(displayItem)
            }

            placementItem.submenu = placementMenu
            menu.addItem(placementItem)

            // Behavior submenu
            let behaviorItem = NSMenuItem(title: "Behavior", action: nil, keyEquivalent: "")
            let behaviorMenu = NSMenu()

            // On Hover
            let hoverItem = NSMenuItem(title: "On Hover", action: nil, keyEquivalent: "")
            let hoverMenu = NSMenu()
            for mode in HoverMode.allCases {
                let item = NSMenuItem(title: mode.displayName, action: #selector(selectHoverMode(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = mode.rawValue
                item.state = mode == selectedHoverMode ? .on : .off
                hoverMenu.addItem(item)
            }
            if selectedHoverMode == .fade {
                hoverMenu.addItem(.separator())
                let opacityHeader = NSMenuItem(title: "Fade To", action: nil, keyEquivalent: "")
                opacityHeader.isEnabled = false
                hoverMenu.addItem(opacityHeader)
                for opacity in HoverOpacity.allCases {
                    let item = NSMenuItem()
                    let rowView = CheckmarkMenuItemView(
                        title: opacity.displayName,
                        isChecked: opacity == selectedHoverOpacity
                    ) { [weak self] in
                        self?.onSelectHoverOpacity?(opacity)
                    }
                    item.view = rowView
                    hoverMenu.addItem(item)
                }
            }
            hoverItem.submenu = hoverMenu
            behaviorMenu.addItem(hoverItem)

            behaviorItem.submenu = behaviorMenu
            menu.addItem(behaviorItem)
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

    @objc private func selectShape(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let shape = PreviewShape(rawValue: raw) else { return }
        onSelectShape?(shape)
    }

    @objc private func selectBorderRadius(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let radius = BorderRadius(rawValue: raw) else { return }
        onSelectBorderRadius?(radius)
    }

    @objc private func selectHoverMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = HoverMode(rawValue: raw) else { return }
        onSelectHoverMode?(mode)
    }

    @objc private func selectHoverOpacity(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let opacity = HoverOpacity(rawValue: raw) else { return }
        onSelectHoverOpacity?(opacity)
    }

    @objc private func selectPlacement(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let placement = PreviewPlacement(rawValue: raw) else { return }
        onSelectPlacement?(placement)
    }

    @objc private func selectScreen(_ sender: NSMenuItem) {
        let screenNumber = sender.representedObject as? Int
        onSelectScreen?(screenNumber)
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

// MARK: - Custom menu item view that doesn't dismiss menu on click

private class CheckmarkMenuItemView: NSView {
    private let onClick: () -> Void
    private let titleLabel = NSTextField(labelWithString: "")
    private let checkLabel = NSTextField(labelWithString: "")
    private var trackingArea: NSTrackingArea?
    private var isHighlighted = false

    init(title: String, isChecked: Bool, onClick: @escaping () -> Void) {
        self.onClick = onClick
        super.init(frame: NSRect(x: 0, y: 0, width: 200, height: 22))

        checkLabel.stringValue = isChecked ? "✓" : ""
        checkLabel.font = .menuFont(ofSize: 13)
        checkLabel.textColor = .labelColor
        checkLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(checkLabel)

        titleLabel.stringValue = title
        titleLabel.font = .menuFont(ofSize: 13)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            checkLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            checkLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkLabel.widthAnchor.constraint(equalToConstant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: checkLabel.trailingAnchor, constant: 2),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHighlighted = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHighlighted = false
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        if isHighlighted {
            NSColor.selectedContentBackgroundColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 1), xRadius: 4, yRadius: 4).fill()
            titleLabel.textColor = .white
            checkLabel.textColor = .white
        } else {
            titleLabel.textColor = .labelColor
            checkLabel.textColor = .labelColor
        }
    }

    override func mouseUp(with event: NSEvent) {
        onClick()
        // Update checkmark visually without closing menu
        if let menu = enclosingMenuItem?.menu {
            for item in menu.items {
                if let view = item.view as? CheckmarkMenuItemView {
                    view.checkLabel.stringValue = ""
                }
            }
        }
        checkLabel.stringValue = "✓"
    }
}
