import SwiftUI
import BuddyCore
import BuddyFirebase

struct SettingsView: View {
    @EnvironmentObject private var store: ClipboardStore
    @AppStorage(BuddySettingsKey.analyticsOptIn) private var analyticsOptIn = false
    @AppStorage(BuddySettingsKey.launchAtLogin) private var launchAtLogin = false

    var body: some View {
        Form {
            Section("History") {
                Stepper("Keep \(store.retentionDays) days", value: $store.retentionDays, in: 1...365)
            }
            Section("Privacy") {
                Toggle("Share anonymous analytics", isOn: $analyticsOptIn)
                    .onChange(of: analyticsOptIn) { enabled in
                        BuddyFirebase.analyticsOptIn = enabled
                        BuddyFirebase.refreshAnalyticsCollection()
                    }
                Toggle("Launch at login", isOn: $launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 240)
        .accessibilityIdentifier("settings")
    }
}
