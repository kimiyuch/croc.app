import SwiftUI
import Sparkle

/// Sparkle's updater, for the app menu. The feed is the latest GitHub release's appcast.xml (SUFeedURL in Info.plist).
@MainActor @Observable
final class Updates {
    @ObservationIgnored private let controller = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    @ObservationIgnored private var observation: NSKeyValueObservation?

    /// False while a check is running.
    private(set) var canCheck = false

    var checksAutomatically: Bool {
        didSet { controller.updater.automaticallyChecksForUpdates = checksAutomatically }
    }

    init() {
        checksAutomatically = controller.updater.automaticallyChecksForUpdates
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            let value = updater.canCheckForUpdates
            Task { @MainActor in self?.canCheck = value }
        }
    }

    func check() { controller.updater.checkForUpdates() }
}
