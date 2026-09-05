import AppKit
import SwiftUI
import BuddyCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    var store: ClipboardStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        BuddyLaunchAtLogin.enableByDefaultOnFirstInstall()

        let store = ClipboardStore.shared
        self.store = store
        let pause = BuddyPauseController.shared

        pause.onPauseChanged = { [weak self] isPaused in
            if isPaused {
                self?.store?.stopMonitoring()
            } else {
                self?.store?.startMonitoring()
            }
            self?.updateStatusIcon()
        }
        pause.restorePersistedPauseIfNeeded()
        if !pause.isPaused {
            store.startMonitoring()
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.action = #selector(togglePopover)
            button.target = self
        }
        statusItem = item
        updateStatusIcon()

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 460)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(store)
                .environmentObject(pause)
        )
        self.popover = popover

        NotificationCenter.default.addObserver(
            forName: .buddyPauseDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusIcon()
            }
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func updateStatusIcon() {
        let paused = BuddyPauseController.shared.isPaused
        let name = paused ? "doc.on.clipboard.fill" : "doc.on.clipboard"
        let description = paused ? "Clipboard Buddy (paused)" : "Clipboard Buddy"
        statusItem?.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: description)
        statusItem?.button?.appearsDisabled = paused
    }
}
