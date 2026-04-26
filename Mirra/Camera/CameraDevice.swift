import AVFoundation

struct CameraDevice: Identifiable, Hashable, Sendable {
    let id: String
    let name: String

    init(device: AVCaptureDevice) {
        self.id = device.uniqueID
        self.name = device.localizedName
    }

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}
