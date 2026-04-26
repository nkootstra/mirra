import AppKit
import Carbon.HIToolbox

@MainActor
final class GlobalHotkeyService {
    private var localMonitor: Any?
    private var globalMonitor: Any?

    // Callbacks for each hotkey
    var onTogglePreview: (() -> Void)?    // Cmd+Shift+M
    var onCycleCamera: (() -> Void)?      // Cmd+Shift+C
    var onToggleMirror: (() -> Void)?     // Cmd+Shift+F
    var onCycleSize: (() -> Void)?        // Cmd+Shift+S
    var onCyclePlacement: (() -> Void)?   // Cmd+Shift+P
    var onCycleShape: (() -> Void)?       // Cmd+Shift+H

    func start() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleEvent(event) == true {
                return nil
            }
            return event
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleEvent(event)
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

    @discardableResult
    private func handleEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command),
              flags.contains(.shift),
              !flags.contains(.option),
              !flags.contains(.control) else {
            return false
        }

        switch event.keyCode {
        case UInt16(kVK_ANSI_M):
            onTogglePreview?()
            return true
        case UInt16(kVK_ANSI_C):
            onCycleCamera?()
            return true
        case UInt16(kVK_ANSI_F):
            onToggleMirror?()
            return true
        case UInt16(kVK_ANSI_S):
            onCycleSize?()
            return true
        case UInt16(kVK_ANSI_P):
            onCyclePlacement?()
            return true
        case UInt16(kVK_ANSI_H):
            onCycleShape?()
            return true
        default:
            return false
        }
    }
}
