import SwiftUI
import BuddyCore
import BuddyUI

struct SettingsView: View {
    @EnvironmentObject private var store: ClipboardStore

    private let brand = BuddyBrand.clipboardBuddy
    private let items: [BuddySettingsItem] = [
        .appearance,
        .preferences,
        .privacy
    ]

    var body: some View {
        BuddySettingsSidebarView(brand: brand, items: items) { item in
            switch item.id {
            case BuddySettingsItem.appearance.id:
                BuddyAppearanceSettingsSection(brand: brand)
            case BuddySettingsItem.preferences.id:
                ClipboardClippingsSettingsSection {
                    store.applyHistoryLimits()
                }
                BuddyPauseSettingsSection()
                ClipboardIgnoredAppsSettingsSection()
                BuddyClearHistorySettingsSection(itemNoun: "clippings") {
                    store.clearAllHistory()
                }
                Section("Startup") {
                    BuddyLaunchAtLoginToggle()
                }
            case BuddySettingsItem.privacy.id:
                SensitivePrivacySettingsSection()
                BuddyLegalLinksSection(brand: brand)
            default:
                EmptyView()
            }
        }
        .accessibilityIdentifier("settings")
    }
}
