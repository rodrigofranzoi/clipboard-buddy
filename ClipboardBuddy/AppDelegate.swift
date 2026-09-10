import AppKit
import SwiftUI
import BuddyCore
import BuddyUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var popoverOutsideClickMonitors: [Any] = []
    var store: ClipboardStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        BuddyAppearanceSettings.applyAppKitAppearance()

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
        popover.delegate = self
        popover.contentSize = NSSize(width: 320, height: 520)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(store)
                .environmentObject(pause)
                .buddyAppearance(brand: .clipboardBuddy)
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

        if BuddyMarketingCapture.isEnabled {
            NSApp.setActivationPolicy(.regular)
            ClipboardMarketingCaptureRunner.startIfNeeded(store: store) { [weak self] in
                self?.showPopoverForCapture()
            }
        } else {
            BuddyMainWindow.presentFirstLaunchExperienceIfNeeded(
                appDisplayName: BuddyBrand.clipboardBuddy.displayName
            )
        }
    }

    @discardableResult
    private func showPopoverForCapture() -> NSWindow? {
        showPopover()
        return popover?.contentViewController?.view.window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc private func togglePopover() {
        guard let popover else { return }
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button, let popover else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
        startOutsideClickMonitoring()
    }

    private func closePopover() {
        popover?.performClose(nil)
        stopOutsideClickMonitoring()
    }

    private func startOutsideClickMonitoring() {
        stopOutsideClickMonitoring()

        if let global = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                self?.dismissPopoverIfClickOutside()
            }
        } {
            popoverOutsideClickMonitors.append(global)
        }

        if let local = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            Task { @MainActor in
                self?.dismissPopoverIfClickOutside()
            }
            return event
        } {
            popoverOutsideClickMonitors.append(local)
        }
    }

    private func stopOutsideClickMonitoring() {
        for monitor in popoverOutsideClickMonitors {
            NSEvent.removeMonitor(monitor)
        }
        popoverOutsideClickMonitors.removeAll()
    }

    private func dismissPopoverIfClickOutside() {
        guard let popover, popover.isShown else { return }

        let location = NSEvent.mouseLocation

        if let popoverWindow = popover.contentViewController?.view.window,
           popoverWindow.frame.contains(location) {
            return
        }

        if let button = statusItem?.button,
           let buttonWindow = button.window {
            let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
            if buttonFrame.contains(location) {
                return
            }
        }

        closePopover()
    }

    private func updateStatusIcon() {
        let paused = BuddyPauseController.shared.isPaused
        let name = paused ? "doc.on.clipboard.fill" : "doc.on.clipboard"
        let description = paused ? "Clipboard Buddy (paused)" : "Clipboard Buddy"
        statusItem?.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: description)
        statusItem?.button?.appearsDisabled = paused
    }
}

extension AppDelegate: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        stopOutsideClickMonitoring()
    }
}
