import AppKit

/// Detects when the cursor enters the MacBook notch region and fires a callback.
/// Uses timer-based polling of NSEvent.mouseLocation which works without
/// Accessibility permission (unlike addGlobalMonitorForEvents).
/// Gracefully no-ops on Macs without a notch.
@MainActor
final class NotchTriggerService {
    var onNotchEntered: (() -> Void)?
    var onNotchExited: (() -> Void)?

    private var pollTimer: Timer?
    private var isInsideNotch = false
    private static let fastInterval: TimeInterval = 0.05   // 20Hz near menu bar
    private static let slowInterval: TimeInterval = 0.25   // 4Hz when far away

    /// The notch region (in screen coordinates), or nil if no notch detected.
    private var notchRect: CGRect?

    func start() {
        notchRect = detectNotchRect()
        guard notchRect != nil else { return } // No notch, nothing to do

        schedulePoll(interval: Self.slowInterval)
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        isInsideNotch = false
    }

    private func checkMouseLocation() {
        guard let notchRect else { return }

        let location = NSEvent.mouseLocation

        // Adaptive polling: speed up when cursor is near the top of the screen
        let distanceFromTop = (notchRect.maxY - location.y)
        let nearMenuBar = distanceFromTop < 100 && distanceFromTop > -10
        let desiredInterval = nearMenuBar ? Self.fastInterval : Self.slowInterval
        if let timer = pollTimer, abs(timer.timeInterval - desiredInterval) > 0.01 {
            schedulePoll(interval: desiredInterval)
        }

        let inside = notchRect.contains(location)

        if inside, !isInsideNotch {
            isInsideNotch = true
            onNotchEntered?()
        } else if !inside, isInsideNotch {
            isInsideNotch = false
            onNotchExited?()
        }
    }

    private func schedulePoll(interval: TimeInterval) {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkMouseLocation()
            }
        }
    }

    // MARK: - Notch detection

    /// Returns the notch region in screen coordinates, or nil if no notch.
    private func detectNotchRect() -> CGRect? {
        guard let builtInScreen = NSScreen.screens.first(where: { screen in
            screen.auxiliaryTopLeftArea != nil
        }) else {
            return nil
        }

        let frame = builtInScreen.frame

        guard let leftArea = builtInScreen.auxiliaryTopLeftArea,
              let rightArea = builtInScreen.auxiliaryTopRightArea else {
            return nil
        }

        // The notch sits between the left and right auxiliary areas.
        let notchLeft = frame.origin.x + leftArea.maxX
        let notchRight = frame.origin.x + rightArea.minX
        let notchWidth = notchRight - notchLeft

        let menuBarHeight = frame.maxY - builtInScreen.visibleFrame.maxY
        let notchTop = frame.maxY
        let notchBottom = frame.maxY - max(menuBarHeight, 38)

        return CGRect(x: notchLeft, y: notchBottom, width: notchWidth, height: notchTop - notchBottom)
    }

    /// Whether this Mac has a notch.
    var hasNotch: Bool {
        detectNotchRect() != nil
    }
}
