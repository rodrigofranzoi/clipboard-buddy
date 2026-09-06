import SwiftUI
import BuddyCore
import BuddyFirebase
import BuddyUI

@main
struct ClipboardBuddyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = ClipboardStore.shared

    private let brand = BuddyBrand.clipboardBuddy

    init() {
        BuddyFirebase.configure()
        BuddyFirebase.log(event: BuddyFirebase.Event.appLaunch)
    }

    var body: some Scene {
        WindowGroup("Clipboard Buddy") {
            DashboardView()
                .environmentObject(store)
                .frame(minWidth: 720, minHeight: 480)
                .background(BuddyMainWindowRegistrar())
                .buddyAppearance(brand: brand)
        }
        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}
