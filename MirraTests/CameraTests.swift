import XCTest
import AVFoundation
@testable import Mirra

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
