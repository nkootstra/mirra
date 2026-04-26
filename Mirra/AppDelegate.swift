import AppKit
import Observation

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = PreferencesStore()
    private let cameraService = CameraService()
    private let statusBarController = StatusBarController()
    private let previewWindowController = PreviewWindowController()

    private let hotkeyService = GlobalHotkeyService()
    private var wasPreviewingBeforeSleep = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Apply saved preferences to services
        cameraService.selectedCameraID = preferences.selectedCameraID
        cameraService.quality = preferences.quality
        previewWindowController.sizePreset = preferences.sizePreset
        previewWindowController.placement = preferences.placement
        previewWindowController.shape = preferences.shape
        previewWindowController.hoverMode = preferences.hoverMode
        previewWindowController.hoverOpacity = preferences.hoverOpacity
        previewWindowController.targetScreenNumber = preferences.screenNumber

        // Set up status bar
        statusBarController.isMirrorEnabled = preferences.isMirrorEnabled
        statusBarController.selectedQuality = preferences.quality
        statusBarController.selectedCameraID = preferences.selectedCameraID
        statusBarController.selectedPlacement = preferences.placement
        statusBarController.selectedSizePreset = preferences.sizePreset
        statusBarController.selectedShape = preferences.shape
        statusBarController.selectedHoverMode = preferences.hoverMode
        statusBarController.selectedHoverOpacity = preferences.hoverOpacity
        statusBarController.selectedScreenNumber = preferences.screenNumber
        statusBarController.isLaunchAtLogin = preferences.launchAtLogin

        // Wire callbacks
        statusBarController.onTogglePreview = { [weak self] in self?.togglePreview() }
        statusBarController.onSelectCamera = { [weak self] id in self?.selectCamera(id) }
        statusBarController.onToggleMirror = { [weak self] enabled in self?.setMirror(enabled) }
        statusBarController.onSelectQuality = { [weak self] quality in self?.setQuality(quality) }
        statusBarController.onSelectPlacement = { [weak self] placement in self?.setPlacement(placement) }
        statusBarController.onSelectSizePreset = { [weak self] preset in self?.setSizePreset(preset) }
        statusBarController.onSelectShape = { [weak self] shape in self?.setShape(shape) }
        statusBarController.onSelectHoverMode = { [weak self] mode in self?.setHoverMode(mode) }
        statusBarController.onSelectHoverOpacity = { [weak self] opacity in self?.setHoverOpacity(opacity) }
        statusBarController.onSelectScreen = { [weak self] num in self?.setScreen(num) }
        statusBarController.onToggleLaunchAtLogin = { [weak self] enabled in self?.setLaunchAtLogin(enabled) }

        statusBarController.setup()

        // Set up camera state change callback
        cameraService.onStateChange = { [weak self] in
            self?.handleCameraStateChange()
        }

        // Request camera access
        cameraService.requestAuthorizationAndDiscover()

        // Auto-restore preview if it was enabled
        if preferences.isPreviewEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.startPreviewIfReady()
            }
        }

        // Set up global hotkey (Cmd+Shift+M)
        hotkeyService.onToggle = { [weak self] in self?.togglePreview() }
        hotkeyService.start()

        // Observe app activation for permission re-check
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        // Observe screen sleep/wake
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(screensDidSleep),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(screensDidWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyService.stop()
        cameraService.stopPreview()
        previewWindowController.close()
    }

    // MARK: - Actions

    private func togglePreview() {
        if cameraService.state == .previewing {
            cameraService.stopPreview()
            previewWindowController.hide()
            preferences.isPreviewEnabled = false
            syncStatusBar()
        } else if cameraService.state == .unauthorized {
            // Menu already shows permission recovery
        } else {
            startPreviewIfReady()
            preferences.isPreviewEnabled = true
        }
    }

    private func selectCamera(_ id: String) {
        preferences.selectedCameraID = id
        cameraService.switchCamera(to: id)
        statusBarController.selectedCameraID = id
        if cameraService.state == .previewing, let session = cameraService.previewSession {
            previewWindowController.show(session: session, isMirrored: preferences.isMirrorEnabled)
        }
        statusBarController.updateMenu()
    }

    private func setMirror(_ enabled: Bool) {
        preferences.isMirrorEnabled = enabled
        statusBarController.isMirrorEnabled = enabled
        if let session = cameraService.previewSession {
            previewWindowController.updateMirror(enabled, session: session)
        }
        statusBarController.updateMenu()
    }

    private func setQuality(_ quality: CameraQuality) {
        preferences.quality = quality
        cameraService.updateQuality(quality)
        statusBarController.selectedQuality = quality
        statusBarController.updateMenu()
    }

    private func setPlacement(_ placement: PreviewPlacement) {
        preferences.placement = placement
        previewWindowController.updatePlacement(placement)
        statusBarController.selectedPlacement = placement
        statusBarController.updateMenu()
    }

    private func setSizePreset(_ preset: PreviewSizePreset) {
        preferences.sizePreset = preset
        previewWindowController.updateSize(preset)
        statusBarController.selectedSizePreset = preset
        statusBarController.updateMenu()
    }

    private func setScreen(_ screenNumber: Int?) {
        preferences.screenNumber = screenNumber
        previewWindowController.updateScreen(screenNumber)
        statusBarController.selectedScreenNumber = screenNumber
        statusBarController.updateMenu()
    }

    private func setShape(_ shape: PreviewShape) {
        preferences.shape = shape
        previewWindowController.updateShape(shape)
        statusBarController.selectedShape = shape
        statusBarController.updateMenu()
    }

    private func setHoverMode(_ mode: HoverMode) {
        preferences.hoverMode = mode
        previewWindowController.hoverMode = mode
        statusBarController.selectedHoverMode = mode
        // Don't call updateMenu() -- let the menu stay open for opacity selection
    }

    private func setHoverOpacity(_ opacity: HoverOpacity) {
        preferences.hoverOpacity = opacity
        previewWindowController.hoverOpacity = opacity
        statusBarController.selectedHoverOpacity = opacity
        // Don't call updateMenu() -- avoid closing the menu
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        preferences.launchAtLogin = enabled
        LaunchAtLoginService.setEnabled(enabled)
        statusBarController.isLaunchAtLogin = enabled
        statusBarController.updateMenu()
    }

    // MARK: - Camera state

    private func handleCameraStateChange() {
        syncStatusBar()

        let state = cameraService.state
        switch state {
        case .previewing:
            if let session = cameraService.previewSession {
                previewWindowController.show(session: session, isMirrored: preferences.isMirrorEnabled)
            }
            statusBarController.updateIcon(previewActive: true)
        case .noCameraAvailable, .cameraInUse, .cameraSuspended, .disconnected:
            statusBarController.updateIcon(previewActive: false)
        case .unauthorized:
            statusBarController.updateIcon(previewActive: false)
            previewWindowController.hide()
        case .ready, .idle:
            statusBarController.updateIcon(previewActive: false)
        }
    }

    private func syncStatusBar() {
        statusBarController.isPreviewEnabled = cameraService.state == .previewing
        statusBarController.availableCameras = cameraService.availableCameras
        statusBarController.selectedCameraID = cameraService.selectedCameraID ?? preferences.selectedCameraID
        statusBarController.cameraState = cameraService.state
        statusBarController.updateMenu()
    }

    private func startPreviewIfReady() {
        let state = cameraService.state
        if state == .ready || state == .idle {
            cameraService.startPreview()
        }
    }

    // MARK: - Notifications

    @objc private func appDidBecomeActive(_ notification: Notification) {
        cameraService.recheckAuthorization()
    }

    @objc private func screensDidSleep(_ notification: Notification) {
        wasPreviewingBeforeSleep = cameraService.state == .previewing
        if wasPreviewingBeforeSleep {
            cameraService.stopPreview()
            previewWindowController.hide()
        }
    }

    @objc private func screensDidWake(_ notification: Notification) {
        if wasPreviewingBeforeSleep {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.cameraService.startPreview()
            }
        }
    }
}
