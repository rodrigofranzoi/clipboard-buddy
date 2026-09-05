import SwiftUI
import BuddyCore
import BuddyUI
import BuddyFirebase

struct SettingsView: View {
    @EnvironmentObject private var store: ClipboardStore
    @AppStorage(BuddySettingsKey.analyticsOptIn) private var analyticsOptIn = false

    var body: some View {
        Form {
            Section("History") {
                Stepper("Keep \(store.retentionDays) days", value: $store.retentionDays, in: 1...365)
            }
            Section("Startup") {
                BuddyLaunchAtLoginToggle()
            }
            Section("Privacy") {
                Toggle("Share anonymous analytics", isOn: $analyticsOptIn)
                    .onChange(of: analyticsOptIn) { enabled in
                        BuddyFirebase.analyticsOptIn = enabled
                        BuddyFirebase.refreshAnalyticsCollection()
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 280)
        .accessibilityIdentifier("settings")
    }
}
