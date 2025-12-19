import SwiftUI
import AppKit

@main
struct NotchHubApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NotchPanel?
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide Dock icon / app switcher — run as accessory app
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupWindow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up status item
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    private func setupStatusItem() {
        // Create a status bar item with variable length
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            // Prefer SF Symbol if available; fallback to text
            if let image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Notch") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "Notch"
            }
        }

        // Build menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Notch", action: #selector(showNotch(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Notch", action: #selector(quitApp(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc private func showNotch(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        window?.orderFrontRegardless()
    }

    @objc private func quitApp(_ sender: Any?) {
        NSApp.terminate(nil)
    }


func setupWindow() {
        guard let screen = NSScreen.main else { return }

        let windowWidth: CGFloat = 1000
        let windowHeight: CGFloat = 600

        let screenFrame = screen.frame

        let xPos = screenFrame.origin.x + (screenFrame.width - windowWidth) / 2
        
        let topOffset: CGFloat = 6  
        
        let yPos = screenFrame.maxY - windowHeight + topOffset

        let panelRect = NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight)
        
        let panel = NotchPanel(contentRect: panelRect, backing: .buffered, defer: false)

        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        
        let hostingView = NSHostingView(rootView: ContentView())
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        
        panel.contentView = hostingView
        panel.orderFrontRegardless()
        
        self.window = panel
    }
}

