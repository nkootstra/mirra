import AppKit
import Carbon.HIToolbox

@MainActor
final class GlobalHotkeyService {
    private var localMonitor: Any?
    private var globalMonitor: Any?
    var onToggle: (() -> Void)?

    func start() {
        // Monitor when app is active
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.matchesHotkey(event) == true {
                self?.onToggle?()
                return nil
            }
            return event
        }

        // Monitor when app is in background
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.matchesHotkey(event) == true {
                self?.onToggle?()
            }
        }
    }

    func stop() {
        if let local = localMonitor {
            NSEvent.removeMonitor(local)
            localMonitor = nil
        }
        if let global = globalMonitor {
            NSEvent.removeMonitor(global)
            globalMonitor = nil
        }
    }

    /// Cmd+Shift+M
    private func matchesHotkey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return event.keyCode == UInt16(kVK_ANSI_M)
            && flags.contains(.command)
            && flags.contains(.shift)
            && !flags.contains(.option)
            && !flags.contains(.control)
    }
}
