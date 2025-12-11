import SwiftUI

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

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupWindow()
    }

    func setupWindow() {
        guard let screen = NSScreen.main else { return }

        // Window dimensions
        let windowWidth: CGFloat = 1000
        let windowHeight: CGFloat = 600

        let fullFrame = screen.frame
        
        // Center horizontally
        let xPos = fullFrame.origin.x + (fullFrame.width - windowWidth) / 2
        
        // Position at absolute top: in macOS coords, top = maxY
        // We want window top edge at screen top edge
        // Window's top = origin.y + height, so: origin.y + height = fullFrame.maxY
        let yPos = fullFrame.maxY - windowHeight

        let panelRect = NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight)
        
        let panel = NotchPanel(contentRect: panelRect, backing: .buffered, defer: false)
        
        // CRITICAL ADDITIONS for top positioning
        panel.level = .screenSaver  // Higher than .floating to go above menu bar
        panel.collectionBehavior.insert(.fullScreenPrimary)  // Allow it in the menu bar area
        
        let hostingView = NSHostingView(rootView: ContentView())
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        
        panel.contentView = hostingView
        panel.orderFrontRegardless()
        
        self.window = panel
    }
}

