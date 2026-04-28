import XCTest
@testable import Mirra

@MainActor
final class NotchPreviewCoordinatorTests: XCTestCase {
    func testPopoverIsPresentedBeforeMicrophoneIndicatorStarts() {
        var events: [String] = []
        var scheduledDelay: TimeInterval?
        var scheduledAction: (() -> Void)?
        let coordinator = NotchPreviewCoordinator(
            presentPopover: { events.append("present-popover") },
            startMicrophoneIndicator: {
                events.append("start-microphone")
            },
            scheduleMicrophoneStartup: { delay, action in
                scheduledDelay = delay
                scheduledAction = action
            }
        )

        coordinator.show()

        XCTAssertEqual(events, ["present-popover"])
        XCTAssertEqual(scheduledDelay, NotchPreviewCoordinator.microphoneStartupDelay)
        XCTAssertGreaterThanOrEqual(
            NotchPreviewCoordinator.microphoneStartupDelay,
            NotchPreviewCoordinator.popoverEntranceDuration
        )

        scheduledAction?()
        XCTAssertEqual(events, ["present-popover", "start-microphone"])
    }

    func testDismissedPopoverDoesNotStartMicrophoneIndicator() {
        var events: [String] = []
        var isPopoverCurrent = true
        var scheduledAction: (() -> Void)?
        let coordinator = NotchPreviewCoordinator(
            presentPopover: { events.append("present-popover") },
            canStartMicrophoneIndicator: { isPopoverCurrent },
            startMicrophoneIndicator: {
                events.append("start-microphone")
            },
            scheduleMicrophoneStartup: { _, action in
                scheduledAction = action
            }
        )

        coordinator.show()
        isPopoverCurrent = false
        scheduledAction?()

        XCTAssertEqual(events, ["present-popover"])
    }
}
