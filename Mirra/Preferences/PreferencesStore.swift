import Foundation
import Observation

@Observable
@MainActor
final class PreferencesStore {
    private let defaults: UserDefaults

    private enum Keys {
        static let selectedCameraID = "selectedCameraID"
        static let isPreviewEnabled = "isPreviewEnabled"
        static let isMirrorEnabled = "isMirrorEnabled"
        static let placement = "placement"
        static let sizePreset = "sizePreset"
        static let shape = "shape"
        static let borderRadius = "borderRadius"
        static let launchAtLogin = "launchAtLogin"
        static let screenNumber = "screenNumber"
        static let hoverMode = "hoverMode"
        static let hoverOpacity = "hoverOpacity"
        static let windowPositionX = "windowPositionX"
        static let windowPositionY = "windowPositionY"
        static let clickThroughMode = "clickThroughMode"
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

    var placement: PreviewPlacement {
        didSet {
            defaults.set(placement.rawValue, forKey: Keys.placement)
            // Selecting a placement clears saved drag position
            windowPosition = nil
        }
    }

    var sizePreset: PreviewSizePreset {
        didSet { defaults.set(sizePreset.rawValue, forKey: Keys.sizePreset) }
    }

    var shape: PreviewShape {
        didSet { defaults.set(shape.rawValue, forKey: Keys.shape) }
    }

    var borderRadius: BorderRadius {
        didSet { defaults.set(borderRadius.rawValue, forKey: Keys.borderRadius) }
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

    var windowPosition: CGPoint? {
        didSet {
            if let windowPosition {
                defaults.set(Double(windowPosition.x), forKey: Keys.windowPositionX)
                defaults.set(Double(windowPosition.y), forKey: Keys.windowPositionY)
            } else {
                defaults.removeObject(forKey: Keys.windowPositionX)
                defaults.removeObject(forKey: Keys.windowPositionY)
            }
        }
    }

    var clickThroughMode: ClickThroughMode {
        didSet {
            defaults.set(clickThroughMode.rawValue, forKey: Keys.clickThroughMode)
            if clickThroughMode == .clickThrough {
                hoverMode = .none
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.selectedCameraID = defaults.string(forKey: Keys.selectedCameraID)
        self.isPreviewEnabled = defaults.bool(forKey: Keys.isPreviewEnabled)
        self.isMirrorEnabled = defaults.object(forKey: Keys.isMirrorEnabled) == nil
            ? true
            : defaults.bool(forKey: Keys.isMirrorEnabled)
        self.placement = PreviewPlacement(rawValue: defaults.string(forKey: Keys.placement) ?? "") ?? .bottomTrailing
        self.sizePreset = PreviewSizePreset(rawValue: defaults.string(forKey: Keys.sizePreset) ?? "") ?? .medium
        self.shape = PreviewShape(rawValue: defaults.string(forKey: Keys.shape) ?? "") ?? .rectangle
        self.borderRadius = BorderRadius(rawValue: defaults.string(forKey: Keys.borderRadius) ?? "") ?? .medium
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.screenNumber = defaults.object(forKey: Keys.screenNumber) as? Int
        self.hoverMode = HoverMode(rawValue: defaults.string(forKey: Keys.hoverMode) ?? "") ?? .fade
        self.hoverOpacity = HoverOpacity(rawValue: defaults.string(forKey: Keys.hoverOpacity) ?? "") ?? .thirty
        self.clickThroughMode = ClickThroughMode(rawValue: defaults.string(forKey: Keys.clickThroughMode) ?? "") ?? .normal

        if defaults.object(forKey: Keys.windowPositionX) != nil {
            let x = defaults.double(forKey: Keys.windowPositionX)
            let y = defaults.double(forKey: Keys.windowPositionY)
            self.windowPosition = CGPoint(x: x, y: y)
        } else {
            self.windowPosition = nil
        }
    }
}
