import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupPopover()
        setupEventMonitor()

        // Initialize haptic manager early
        _ = HapticManager.shared

        // Hide dock icon since this is a menu bar app
        NSApp.setActivationPolicy(.accessory)
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            // Use SF Symbol for menu bar icon
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            if let image = NSImage(systemSymbolName: "ipod", accessibilityDescription: "TrayPod") {
                button.image = image.withSymbolConfiguration(config)
            } else {
                // Fallback to music note if ipod symbol not available
                button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "TrayPod")?
                    .withSymbolConfiguration(config)
            }
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 350, height: 560)
        popover?.behavior = .transient
        popover?.animates = true
        popover?.contentViewController = NSHostingController(rootView: iPodView())
    }

    private func setupEventMonitor() {
        // Monitor for clicks outside the popover to close it
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
        }
    }

    @objc private func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Ensure the popover window becomes key to receive keyboard events
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }
}
