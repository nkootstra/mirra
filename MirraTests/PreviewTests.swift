import XCTest
@testable import Mirra

final class PreviewPlacementTests: XCTestCase {
    let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    let windowSize = CGSize(width: 240, height: 180)

    func testTopLeading() {
        let origin = PreviewPlacement.topLeading.origin(for: windowSize, in: screenFrame)
        XCTAssertEqual(origin.x, 20)
        XCTAssertEqual(origin.y, 1080 - 180 - 20)
    }

    func testTopTrailing() {
        let origin = PreviewPlacement.topTrailing.origin(for: windowSize, in: screenFrame)
        XCTAssertEqual(origin.x, 1920 - 240 - 20)
        XCTAssertEqual(origin.y, 1080 - 180 - 20)
    }

    func testBottomLeading() {
        let origin = PreviewPlacement.bottomLeading.origin(for: windowSize, in: screenFrame)
        XCTAssertEqual(origin.x, 20)
        XCTAssertEqual(origin.y, 20)
    }

    func testBottomTrailing() {
        let origin = PreviewPlacement.bottomTrailing.origin(for: windowSize, in: screenFrame)
        XCTAssertEqual(origin.x, 1920 - 240 - 20)
        XCTAssertEqual(origin.y, 20)
    }

    func testCenter() {
        let origin = PreviewPlacement.center.origin(for: windowSize, in: screenFrame)
        XCTAssertEqual(origin.x, 1920 / 2 - 240 / 2)
        XCTAssertEqual(origin.y, 1080 / 2 - 180 / 2)
    }

    func testAllCases() {
        XCTAssertEqual(PreviewPlacement.allCases.count, 5)
    }
}

final class PreviewSizePresetTests: XCTestCase {
    func testSizes() {
        XCTAssertEqual(PreviewSizePreset.small.size, CGSize(width: 160, height: 120))
        XCTAssertEqual(PreviewSizePreset.medium.size, CGSize(width: 240, height: 180))
        XCTAssertEqual(PreviewSizePreset.large.size, CGSize(width: 320, height: 240))
    }

    func testAllCases() {
        XCTAssertEqual(PreviewSizePreset.allCases.count, 3)
    }

    func testRawValueRoundTrip() {
        for preset in PreviewSizePreset.allCases {
            XCTAssertEqual(PreviewSizePreset(rawValue: preset.rawValue), preset)
        }
    }
}

@MainActor
final class WindowPositionPersistenceTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let suiteName = "WindowPositionTests"
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        return UserDefaults(suiteName: suiteName)!
    }

    func testSavedPositionIsRestored() {
        let defaults = freshDefaults()
        let store = PreferencesStore(defaults: defaults)
        store.windowPosition = CGPoint(x: 100, y: 200)

        let store2 = PreferencesStore(defaults: defaults)
        XCTAssertEqual(store2.windowPosition, CGPoint(x: 100, y: 200))
    }

    func testDefaultPositionIsNil() {
        let defaults = freshDefaults()
        let store = PreferencesStore(defaults: defaults)
        XCTAssertNil(store.windowPosition)
    }

    func testSelectingPlacementClearsPosition() {
        let defaults = freshDefaults()
        let store = PreferencesStore(defaults: defaults)
        store.windowPosition = CGPoint(x: 100, y: 200)
        store.placement = .topLeading
        XCTAssertNil(store.windowPosition)
    }
}
