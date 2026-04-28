import Foundation

@MainActor
struct NotchPreviewCoordinator {
    typealias Scheduler = (_ delay: TimeInterval, _ action: @escaping @MainActor () -> Void) -> Void

    static let popoverEntranceDuration: TimeInterval = 0.16
    static let microphoneStartupDelay: TimeInterval = popoverEntranceDuration

    let presentPopover: () -> Void
    let canStartMicrophoneIndicator: () -> Bool
    let startMicrophoneIndicator: () -> Void
    let scheduleMicrophoneStartup: Scheduler

    init(
        presentPopover: @escaping () -> Void,
        canStartMicrophoneIndicator: @escaping () -> Bool = { true },
        startMicrophoneIndicator: @escaping () -> Void,
        scheduleMicrophoneStartup: @escaping Scheduler = { delay, action in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                MainActor.assumeIsolated {
                    action()
                }
            }
        }
    ) {
        self.presentPopover = presentPopover
        self.canStartMicrophoneIndicator = canStartMicrophoneIndicator
        self.startMicrophoneIndicator = startMicrophoneIndicator
        self.scheduleMicrophoneStartup = scheduleMicrophoneStartup
    }

    func show() {
        presentPopover()
        scheduleMicrophoneStartup(Self.microphoneStartupDelay) {
            guard canStartMicrophoneIndicator() else { return }
            startMicrophoneIndicator()
        }
    }
}
