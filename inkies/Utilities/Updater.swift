import Sparkle
import SwiftUI

/// A class that handles Sparkle updates for the application.
@Observable
final class SparkleUpdater {
    private let controller: SPUStandardUpdaterController
    
    var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates
    }
    
    init() {
        // The standard updater controller handles the lifecycle of the updater.
        // It will automatically start the updater.
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }
    
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
