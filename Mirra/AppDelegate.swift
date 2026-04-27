import AppKit
import AVFoundation
import Observation
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = PreferencesStore()
    private let cameraService = CameraService()
    private lazy var statusBarController = StatusBarController(preferences: preferences)
    private let previewWindowController = PreviewWindowController()

    private let hotkeyService = GlobalHotkeyService()
    private let notchTriggerService = NotchTriggerService()
    private let micCheck = MicLevelService()
    private var notchPanel: NSPanel?
    private var isNotchPreviewActive = false
    private var wasPreviewingBeforeSleep = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Apply saved preferences to services
        cameraService.selectedCameraID = preferences.selectedCameraID
        previewWindowController.sizePreset = preferences.sizePreset
        previewWindowController.placement = preferences.placement
        previewWindowController.shape = preferences.shape
        previewWindowController.borderRadius = preferences.borderRadius
        previewWindowController.hoverMode = preferences.hoverMode
        previewWindowController.hoverOpacity = preferences.hoverOpacity
        previewWindowController.targetScreenNumber = preferences.screenNumber
        previewWindowController.savedWindowPosition = preferences.windowPosition
        previewWindowController.onWindowPositionChanged = { [weak self] point in
            self?.preferences.windowPosition = point
        }
        previewWindowController.onCloseRequested = { [weak self] in
            self?.togglePreview()
        }

        // Wire callbacks
        statusBarController.onTogglePreview = { [weak self] in self?.togglePreview() }
        statusBarController.onSelectCamera = { [weak self] id in self?.selectCamera(id) }
        statusBarController.onToggleMirror = { [weak self] enabled in self?.setMirror(enabled) }
        statusBarController.onSelectPlacement = { [weak self] placement in self?.setPlacement(placement) }
        statusBarController.onSelectSizePreset = { [weak self] preset in self?.setSizePreset(preset) }
        statusBarController.onSelectShape = { [weak self] shape in self?.setShape(shape) }
        statusBarController.onSelectBorderRadius = { [weak self] radius in self?.setBorderRadius(radius) }
        statusBarController.onSelectHoverMode = { [weak self] mode in self?.setHoverMode(mode) }
        statusBarController.onSelectHoverOpacity = { [weak self] opacity in self?.setHoverOpacity(opacity) }
        statusBarController.onSelectScreen = { [weak self] num in self?.setScreen(num) }
        statusBarController.onToggleLaunchAtLogin = { [weak self] enabled in self?.setLaunchAtLogin(enabled) }
        statusBarController.onSelectClickThroughMode = { [weak self] mode in self?.setClickThroughMode(mode) }

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

        // Set up global hotkeys
        hotkeyService.onTogglePreview = { [weak self] in self?.togglePreview() }
        hotkeyService.onCycleCamera = { [weak self] in self?.cycleCamera() }
        hotkeyService.onToggleMirror = { [weak self] in self?.setMirror(!(self?.preferences.isMirrorEnabled ?? true)) }
        hotkeyService.onCycleSize = { [weak self] in self?.cycleSize() }
        hotkeyService.onCyclePlacement = { [weak self] in self?.cyclePlacement() }
        hotkeyService.onCycleShape = { [weak self] in self?.cycleShape() }
        hotkeyService.start()

        // Set up notch trigger (no-ops on non-notch Macs)
        notchTriggerService.onNotchEntered = { [weak self] in self?.showNotchPreview() }
        notchTriggerService.onNotchExited = { [weak self] in self?.hideNotchPreview() }
        notchTriggerService.start()

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
            cameraService.pausePreview()
            previewWindowController.hide()
            preferences.isPreviewEnabled = false
            syncStatusBar()
        } else if cameraService.state == .paused {
            cameraService.resumePreview()
            if let session = cameraService.previewSession {
                previewWindowController.show(session: session, isMirrored: preferences.isMirrorEnabled)
            }
            preferences.isPreviewEnabled = true
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
        if cameraService.state == .previewing, let session = cameraService.previewSession {
            previewWindowController.show(session: session, isMirrored: preferences.isMirrorEnabled)
        }
        statusBarController.updateMenu()
    }

    private func setMirror(_ enabled: Bool) {
        preferences.isMirrorEnabled = enabled
        if let session = cameraService.previewSession {
            previewWindowController.updateMirror(enabled, session: session)
        }
        statusBarController.updateMenu()
    }

    private func setPlacement(_ placement: PreviewPlacement) {
        preferences.placement = placement
        previewWindowController.updatePlacement(placement)
        statusBarController.updateMenu()
    }

    private func setSizePreset(_ preset: PreviewSizePreset) {
        preferences.sizePreset = preset
        previewWindowController.updateSize(preset)
        statusBarController.updateMenu()
    }

    private func setScreen(_ screenNumber: Int?) {
        preferences.screenNumber = screenNumber
        previewWindowController.updateScreen(screenNumber)
        statusBarController.updateMenu()
    }

    private func setShape(_ shape: PreviewShape) {
        preferences.shape = shape
        previewWindowController.updateShape(shape)
        statusBarController.updateMenu()
    }

    private func setBorderRadius(_ radius: BorderRadius) {
        preferences.borderRadius = radius
        previewWindowController.updateBorderRadius(radius)
        statusBarController.updateMenu()
    }

    private func setHoverMode(_ mode: HoverMode) {
        preferences.hoverMode = mode
        previewWindowController.hoverMode = mode
        // Don't call updateMenu() -- let the menu stay open for opacity selection
    }

    private func setHoverOpacity(_ opacity: HoverOpacity) {
        preferences.hoverOpacity = opacity
        previewWindowController.hoverOpacity = opacity
        // Don't call updateMenu() -- avoid closing the menu
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        preferences.launchAtLogin = enabled
        LaunchAtLoginService.setEnabled(enabled)
        statusBarController.updateMenu()
    }

    private func setClickThroughMode(_ mode: ClickThroughMode) {
        preferences.clickThroughMode = mode
        previewWindowController.updateClickThrough(mode)
        statusBarController.updateMenu()
    }

    // MARK: - Notch preview

    private func showNotchPreview() {
        guard notchPanel == nil else { return }

        // Start camera if not already running
        var session = cameraService.previewSession
        if session == nil {
            cameraService.startPreview()
            session = cameraService.previewSession
        }
        guard let session else { return }

        isNotchPreviewActive = true

        // Start mic monitoring
        micCheck.startMonitoring()

        guard let builtInScreen = NSScreen.screens.first(where: { $0.auxiliaryTopLeftArea != nil }),
              let leftArea = builtInScreen.auxiliaryTopLeftArea,
              let rightArea = builtInScreen.auxiliaryTopRightArea else { return }

        let frame = builtInScreen.frame
        let notchCenterX = frame.origin.x + (leftArea.maxX + rightArea.minX) / 2
        let menuBarBottom = builtInScreen.visibleFrame.maxY

        let arrowHeight = NotchPreviewView.arrowHeight
        let previewWidth: CGFloat = 360
        let previewHeight: CGFloat = 270
        let totalHeight = previewHeight + arrowHeight

        let panelRect = NSRect(
            x: notchCenterX - previewWidth / 2,
            y: menuBarBottom - totalHeight,
            width: previewWidth,
            height: totalHeight
        )

        let view = NotchPreviewView(
            session: session,
            isMirrored: preferences.isMirrorEnabled,
            micLevel: micCheck
        )

        let panel = NSPanel(
            contentRect: panelRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar + 1
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hostingView = NSHostingView(rootView:
            view.frame(width: previewWidth, height: totalHeight)
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: previewWidth, height: totalHeight)
        panel.contentView = hostingView
        panel.orderFrontRegardless()

        notchPanel = panel
    }

    private func hideNotchPreview() {
        notchPanel?.orderOut(nil)
        notchPanel = nil
        isNotchPreviewActive = false

        // Stop mic monitoring
        micCheck.stopMonitoring()

        // If the main preview wasn't enabled, stop the camera
        if !preferences.isPreviewEnabled {
            cameraService.stopPreview()
        }
    }

    // MARK: - Cycle helpers (for keyboard shortcuts)

    private func cycleCamera() {
        let cameras = cameraService.availableCameras
        guard cameras.count > 1 else { return }
        let currentID = cameraService.selectedCameraID ?? cameras.first?.id
        let currentIndex = cameras.firstIndex(where: { $0.id == currentID }) ?? 0
        let nextIndex = (currentIndex + 1) % cameras.count
        selectCamera(cameras[nextIndex].id)
    }

    private func cycleSize() {
        let all = PreviewSizePreset.allCases
        let currentIndex = all.firstIndex(of: preferences.sizePreset) ?? 0
        let next = all[(currentIndex + 1) % all.count]
        setSizePreset(next)
    }

    private func cyclePlacement() {
        let all = PreviewPlacement.allCases
        let currentIndex = all.firstIndex(of: preferences.placement) ?? 0
        let next = all[(currentIndex + 1) % all.count]
        setPlacement(next)
    }

    private func cycleShape() {
        let all = PreviewShape.allCases
        let currentIndex = all.firstIndex(of: preferences.shape) ?? 0
        let next = all[(currentIndex + 1) % all.count]
        setShape(next)
    }

    // MARK: - Camera state

    private func handleCameraStateChange() {
        syncStatusBar()

        let state = cameraService.state
        switch state {
        case .previewing:
            if let session = cameraService.previewSession, !isNotchPreviewActive {
                previewWindowController.show(session: session, isMirrored: preferences.isMirrorEnabled)
            }
            statusBarController.updateIcon(previewActive: !isNotchPreviewActive)
        case .paused:
            // Window is hidden but session is alive — show icon as inactive
            statusBarController.updateIcon(previewActive: false)
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
        let state = cameraService.state
        wasPreviewingBeforeSleep = state == .previewing || state == .paused
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
