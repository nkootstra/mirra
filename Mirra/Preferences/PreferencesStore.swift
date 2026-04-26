import Foundation
import Observation

@Observable
@MainActor
final class PreferencesStore {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let selectedCameraID = "selectedCameraID"
        static let isPreviewEnabled = "isPreviewEnabled"
        static let isMirrorEnabled = "isMirrorEnabled"
        static let quality = "quality"
        static let placement = "placement"
        static let sizePreset = "sizePreset"
        static let shape = "shape"
        static let launchAtLogin = "launchAtLogin"
        static let screenNumber = "screenNumber"
        static let hoverMode = "hoverMode"
        static let hoverOpacity = "hoverOpacity"
    }

    var selectedCameraID: String? {
        didSet { defaults.set(selectedCameraID, forKey: Keys.selectedCameraID) }
    }

    var isPreviewEnabled: Bool {
        didSet { defaults.set(isPreviewEnabled, forKey: Keys.isPreviewEnabled) }
    }

    var isMirrorEnabled: Bool {
        didSet { defaults.set(isMirrorEnabled, forKey: Keys.isMirrorEnabled) }
    }

    var quality: CameraQuality {
        didSet { defaults.set(quality.rawValue, forKey: Keys.quality) }
    }

    var placement: PreviewPlacement {
        didSet { defaults.set(placement.rawValue, forKey: Keys.placement) }
    }

    var sizePreset: PreviewSizePreset {
        didSet { defaults.set(sizePreset.rawValue, forKey: Keys.sizePreset) }
    }

    var shape: PreviewShape {
        didSet { defaults.set(shape.rawValue, forKey: Keys.shape) }
    }

    var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    var screenNumber: Int? {
        didSet {
            if let screenNumber {
                defaults.set(screenNumber, forKey: Keys.screenNumber)
            } else {
                defaults.removeObject(forKey: Keys.screenNumber)
            }
        }
    }

    var hoverMode: HoverMode {
        didSet { defaults.set(hoverMode.rawValue, forKey: Keys.hoverMode) }
    }

    var hoverOpacity: HoverOpacity {
        didSet { defaults.set(hoverOpacity.rawValue, forKey: Keys.hoverOpacity) }
    }

    init() {
        self.selectedCameraID = defaults.string(forKey: Keys.selectedCameraID)
        self.isPreviewEnabled = defaults.bool(forKey: Keys.isPreviewEnabled)
        self.isMirrorEnabled = defaults.object(forKey: Keys.isMirrorEnabled) == nil
            ? true  // default to mirrored
            : defaults.bool(forKey: Keys.isMirrorEnabled)
        self.quality = CameraQuality(rawValue: defaults.string(forKey: Keys.quality) ?? "") ?? .medium
        self.placement = PreviewPlacement(rawValue: defaults.string(forKey: Keys.placement) ?? "") ?? .bottomTrailing
        self.sizePreset = PreviewSizePreset(rawValue: defaults.string(forKey: Keys.sizePreset) ?? "") ?? .medium
        self.shape = PreviewShape(rawValue: defaults.string(forKey: Keys.shape) ?? "") ?? .rectangle
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.screenNumber = defaults.object(forKey: Keys.screenNumber) as? Int
        self.hoverMode = HoverMode(rawValue: defaults.string(forKey: Keys.hoverMode) ?? "") ?? .fade
        self.hoverOpacity = HoverOpacity(rawValue: defaults.string(forKey: Keys.hoverOpacity) ?? "") ?? .thirty
    }
}
