import AppKit
import Foundation
import SwiftUI
import BuddyCore
import BuddyUI

@MainActor
enum ClipboardMarketingCaptureRunner {
    private static var hostedWindow: NSWindow?

    static func startIfNeeded(store: ClipboardStore, showPopover: @escaping () -> NSWindow?) {
        guard BuddyMarketingCapture.isEnabled else { return }

        store.stopMonitoring()
        store.installMarketingSeed()

        Task { @MainActor in
            do {
                let out = try BuddyMarketingCapture.ensureOutputDirectory()
                await BuddyMarketingCapture.sleep(0.4)
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)

                let window = makeHostedWindow(store: store)
                window.makeKeyAndOrderFront(nil)
                await BuddyMarketingCapture.sleep(0.8)

                try await captureMainScenes(store: store, window: window, out: out)
                try await captureMenubarScenes(showPopover: showPopover, out: out)

                print("[BuddyMarketing] Clipboard Buddy captures written to \(out.path)")
                NSApp.terminate(nil)
            } catch {
                fputs("[BuddyMarketing] ERROR: \(error)\n", stderr)
                NSApp.terminate(nil)
            }
        }
    }

    private static func makeHostedWindow(store: ClipboardStore) -> NSWindow {
        if let hostedWindow {
            return hostedWindow
        }
        let root = DashboardView()
            .environmentObject(store)
            .frame(minWidth: 720, minHeight: 480)
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Clipboard Buddy"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 1040, height: 680))
        window.center()
        window.isReleasedWhenClosed = false
        hostedWindow = window
        BuddyMainWindow.register(window)
        return window
    }

    private static func captureMainScenes(store: ClipboardStore, window: NSWindow, out: URL) async throws {
        let scenes: [(String, UUID)] = [
            ("history", ClipboardStore.MarketingClipID.url),
            ("tags", ClipboardStore.MarketingClipID.password),
            ("detail", ClipboardStore.MarketingClipID.release)
        ]
        for (scene, id) in scenes {
            store.selectedId = id
            BuddyMarketingCapture.stage(scene)
            await BuddyMarketingCapture.sleep(1.0)
            try BuddyMarketingCapture.captureWindow(window, to: out.appendingPathComponent("\(scene).png"))
        }

        if store.items.contains(where: { $0.id == ClipboardStore.MarketingClipID.share }) {
            store.selectedId = ClipboardStore.MarketingClipID.share
            BuddyMarketingCapture.stage("qr")
            await BuddyMarketingCapture.sleep(1.4)
            if let sheet = NSApp.windows.first(where: { $0.isVisible && $0 != window && $0.frame.width > 200 }) {
                try BuddyMarketingCapture.captureWindow(sheet, to: out.appendingPathComponent("qr.png"))
            } else {
                try BuddyMarketingCapture.captureWindow(window, to: out.appendingPathComponent("qr.png"))
            }
            for w in NSApp.windows where w.isSheet {
                w.sheetParent?.endSheet(w)
            }
            await BuddyMarketingCapture.sleep(0.3)
        }
    }

    private static func captureMenubarScenes(showPopover: @escaping () -> NSWindow?, out: URL) async throws {
        hostedWindow?.orderOut(nil)
        await BuddyMarketingCapture.sleep(0.3)
        guard let popoverWindow = showPopover() else {
            throw BuddyMarketingCapture.CaptureError.missingPopoverWindow
        }
        await BuddyMarketingCapture.sleep(0.8)
        try BuddyMarketingCapture.captureWindow(popoverWindow, to: out.appendingPathComponent("favorites.png"))
        try BuddyMarketingCapture.captureWindow(popoverWindow, to: out.appendingPathComponent("menubar.png"))
    }
}
