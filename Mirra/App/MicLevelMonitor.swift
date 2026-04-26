import AVFoundation

/// Checks whether a microphone input device is available.
/// Does not actively capture audio to avoid introducing noise.
@MainActor
final class MicCheckService: ObservableObject {
    @Published var isAvailable: Bool = false

    func check() {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        ).devices
        isAvailable = !devices.isEmpty
    }
}
