import SwiftUI
import BuddyFirebase

@main
struct ClipboardBuddyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = ClipboardStore.shared

    init() {
        BuddyFirebase.configure()
        BuddyFirebase.log(event: BuddyFirebase.Event.appLaunch)
    }

    var body: some Scene {
        WindowGroup("Clipboard Buddy") {
            DashboardView()
                .environmentObject(store)
                .frame(minWidth: 720, minHeight: 480)
        }
        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}
