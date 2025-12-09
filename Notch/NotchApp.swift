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
        // Get the primary screen
        guard let screen = NSScreen.main else { return }
        
        let windowWidth: CGFloat = 600
        let windowHeight: CGFloat = 300 // Tall enough to hold the expanded view
        
        // X: Center horizontally
        let xPos = screen.frame.origin.x + (screen.frame.width - windowWidth) / 2
        
        // Y: STRICT TOP ALIGNMENT
        // screen.frame.maxY is the absolute top pixel of the monitor.
        // We subtract windowHeight to place the window's top edge exactly at the screen's top edge.
        let yPos = screen.frame.maxY - windowHeight
        
        let panelRect = NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight)
        
        let panel = NotchPanel(contentRect: panelRect, backing: .buffered, defer: false)
        
        let hostingView = NSHostingView(rootView: ContentView())
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        
        panel.contentView = hostingView
        panel.orderFrontRegardless()
        
        self.window = panel
    }
}
