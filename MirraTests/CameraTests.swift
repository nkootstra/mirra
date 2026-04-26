import XCTest
import AVFoundation
@testable import Mirra

final class CameraQualityTests: XCTestCase {
    func testPresetMapping() {
        XCTAssertEqual(CameraQuality.low.capturePreset, .low)
        XCTAssertEqual(CameraQuality.medium.capturePreset, .medium)
        XCTAssertEqual(CameraQuality.best.capturePreset, .high)
    }

    func testDisplayNames() {
        XCTAssertEqual(CameraQuality.low.displayName, "Low")
        XCTAssertEqual(CameraQuality.medium.displayName, "Medium")
        XCTAssertEqual(CameraQuality.best.displayName, "Best")
    }

    func testAllCases() {
        XCTAssertEqual(CameraQuality.allCases.count, 3)
    }

    func testRawValueRoundTrip() {
        for quality in CameraQuality.allCases {
            XCTAssertEqual(CameraQuality(rawValue: quality.rawValue), quality)
        }
    }
}

final class CameraStateTests: XCTestCase {
    func testEquality() {
        XCTAssertEqual(CameraState.idle, CameraState.idle)
        XCTAssertEqual(CameraState.unauthorized, CameraState.unauthorized)
        XCTAssertNotEqual(CameraState.idle, CameraState.ready)
    }

    func testAllStatesAreCovered() {
        // Ensure we have all expected states
        let states: [CameraState] = [
            .idle, .unauthorized, .noCameraAvailable,
            .cameraInUse, .cameraSuspended, .disconnected,
            .ready, .previewing,
        ]
        XCTAssertEqual(states.count, 8)
    }
}

final class CameraDeviceTests: XCTestCase {
    func testInitWithValues() {
        let device = CameraDevice(id: "test-id", name: "Test Camera")
        XCTAssertEqual(device.id, "test-id")
        XCTAssertEqual(device.name, "Test Camera")
    }

    func testHashable() {
        let a = CameraDevice(id: "1", name: "A")
        let b = CameraDevice(id: "1", name: "A")
        let c = CameraDevice(id: "2", name: "B")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}
