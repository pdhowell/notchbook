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

        let screenFrame = screen.frame
        
        // Center horizontally
        let xPos = screenFrame.origin.x + (screenFrame.width - windowWidth) / 2
        
        // Position slightly above the screen top to sit in menu bar perfectly
        // Add a small offset upward (negative offset pushes window up)
        let topOffset: CGFloat = 6  // Adjust this value to fine-tune (try 4-10)
        
        let yPos = screenFrame.maxY - windowHeight + topOffset

        let panelRect = NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight)
        
        let panel = NotchPanel(contentRect: panelRect, backing: .buffered, defer: false)
        
        // CRITICAL: Use .statusBar level to appear ABOVE menu bar
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        
        let hostingView = NSHostingView(rootView: ContentView())
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        
        panel.contentView = hostingView
        panel.orderFrontRegardless()
        
        self.window = panel
    }
}

