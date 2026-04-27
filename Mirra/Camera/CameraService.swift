import AVFoundation
import Observation

@Observable
@MainActor
final class CameraService {
    private(set) var state: CameraState = .idle {
        didSet { if state != oldValue { onStateChange?() } }
    }
    private(set) var availableCameras: [CameraDevice] = [] {
        didSet { onStateChange?() }
    }

    private var captureSession: AVCaptureSession?
    private var currentInput: AVCaptureDeviceInput?
    private var discoverySession: AVCaptureDevice.DiscoverySession?
    private let sessionQueue = DispatchQueue(label: "com.mirra.captureSession")

    var selectedCameraID: String?
    /// The camera the user explicitly chose. Used to auto-restore after reconnection.
    var preferredCameraID: String?
    var onStateChange: (() -> Void)?

    // MARK: - Public

    var previewSession: AVCaptureSession? { captureSession }

    func requestAuthorizationAndDiscover() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            setupDiscovery()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    if granted {
                        self?.setupDiscovery()
                    } else {
                        self?.state = .unauthorized
                    }
                }
            }
        case .denied, .restricted:
            state = .unauthorized
        @unknown default:
            state = .unauthorized
        }
    }

    func startPreview() {
        guard state == .ready || state == .idle else {
            if state == .unauthorized || state == .noCameraAvailable {
                return
            }
            if state == .previewing { return }
            return
        }

        guard let device = resolveDevice() else {
            state = .noCameraAvailable
            return
        }

        let session = AVCaptureSession()
        session.sessionPreset = .photo

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                state = .noCameraAvailable
                return
            }
            session.addInput(input)
            currentInput = input
        } catch {
            state = .noCameraAvailable
            return
        }

        captureSession = session
        sessionQueue.async { session.startRunning() }
        state = .previewing
        observeDevice(device)
    }

    func stopPreview() {
        let session = captureSession
        let input = currentInput
        sessionQueue.async {
            session?.stopRunning()
            if let input { session?.removeInput(input) }
        }
        currentInput = nil
        captureSession = nil
        removeDeviceObservers()

        if state == .previewing {
            state = availableCameras.isEmpty ? .noCameraAvailable : .ready
        }
    }

    func switchCamera(to cameraID: String) {
        selectedCameraID = cameraID
        preferredCameraID = cameraID
        if state == .previewing {
            stopPreview()
            startPreview()
        }
    }

    func recheckAuthorization() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .authorized && state == .unauthorized {
            setupDiscovery()
        } else if status != .authorized {
            state = .unauthorized
        }
    }

    // MARK: - Private

    private func setupDiscovery() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        self.discoverySession = discovery
        refreshCameraList()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(devicesChanged),
            name: NSNotification.Name.AVCaptureDeviceWasConnected,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(devicesChanged),
            name: NSNotification.Name.AVCaptureDeviceWasDisconnected,
            object: nil
        )
    }

    private func refreshCameraList() {
        guard let discovery = discoverySession else { return }
        availableCameras = discovery.devices.map { CameraDevice(device: $0) }

        if availableCameras.isEmpty {
            state = .noCameraAvailable
        } else if state == .idle || state == .noCameraAvailable {
            state = .ready
        }

        // If preferred camera is back, switch to it
        if let preferred = preferredCameraID,
           availableCameras.contains(where: { $0.id == preferred }) {
            selectedCameraID = preferred
        }

        // If selected camera is gone, fall back to first available
        if let selected = selectedCameraID,
           !availableCameras.contains(where: { $0.id == selected }) {
            selectedCameraID = availableCameras.first?.id
        }

        if selectedCameraID == nil {
            selectedCameraID = availableCameras.first?.id
        }
    }

    private func resolveDevice() -> AVCaptureDevice? {
        if let id = selectedCameraID,
           let device = AVCaptureDevice(uniqueID: id) {
            return device
        }
        return AVCaptureDevice.default(for: .video)
    }

    @objc private func devicesChanged(_ notification: Notification) {
        Task { @MainActor in
            let wasPreviewing = state == .previewing
            let previousCameraID = currentInput?.device.uniqueID
            refreshCameraList()

            if wasPreviewing && state == .noCameraAvailable {
                stopPreview()
                state = .disconnected
            } else if wasPreviewing,
                      let currentDevice = currentInput?.device,
                      !currentDevice.isConnected {
                stopPreview()
                state = .disconnected
                // Try to recover with another camera
                if !availableCameras.isEmpty {
                    startPreview()
                }
            } else if wasPreviewing,
                      let preferred = preferredCameraID,
                      preferred != previousCameraID,
                      selectedCameraID == preferred {
                // Preferred camera just came back — switch to it
                stopPreview()
                startPreview()
            }
        }
    }

    // MARK: - Device observation

    private var deviceObservation: NSKeyValueObservation?
    private var suspendedObservation: NSKeyValueObservation?

    private func observeDevice(_ device: AVCaptureDevice) {
        removeDeviceObservers()

        deviceObservation = device.observe(\.isInUseByAnotherApplication) { [weak self] device, _ in
            let inUse = device.isInUseByAnotherApplication
            Task { @MainActor in
                if inUse {
                    self?.state = .cameraInUse
                } else if self?.state == .cameraInUse {
                    self?.state = .previewing
                }
            }
        }

        suspendedObservation = device.observe(\.isSuspended) { [weak self] device, _ in
            let suspended = device.isSuspended
            Task { @MainActor in
                if suspended {
                    self?.state = .cameraSuspended
                } else if self?.state == .cameraSuspended {
                    self?.state = .previewing
                }
            }
        }
    }

    private func removeDeviceObservers() {
        deviceObservation?.invalidate()
        deviceObservation = nil
        suspendedObservation?.invalidate()
        suspendedObservation = nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
