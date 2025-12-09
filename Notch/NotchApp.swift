//import SwiftUI
//
//@main
//struct NotchHubApp: App {
//    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
//
//    var body: some Scene {
//        Settings {
//            EmptyView()
//        }
//    }
//}
//
//class AppDelegate: NSObject, NSApplicationDelegate {
//    var window: NotchPanel?
//
//    func applicationDidFinishLaunching(_ notification: Notification) {
//        setupWindow()
//    }
//
//    func setupWindow() {
//    // Get the primary screen and its visible frame (excludes menu bar / notch area)
//    guard let screen = NSScreen.main else { return }
//
//    let windowWidth: CGFloat = 600
//    let windowHeight: CGFloat = 300 // Tall enough to hold the expanded view
//
//    // Use visibleFrame to avoid placing the window under the menu bar / notch
//    let visible = screen.visibleFrame
//
//    // X: Center horizontally within the visible area
//    let xPos = visible.origin.x + (visible.width - windowWidth) / 2
//
//    // Y: Place window's top edge at the top of the visible frame
//    let yPos = visible.maxY - windowHeight
//
//    let panelRect = NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight)
//        
//        let panel = NotchPanel(contentRect: panelRect, backing: .buffered, defer: false)
//        
//        let hostingView = NSHostingView(rootView: ContentView())
//        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
//        
//        panel.contentView = hostingView
//        panel.orderFrontRegardless()
//        
//        self.window = panel
//    }
//}


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
            
            let windowWidth: CGFloat = 1000
            let windowHeight: CGFloat = 600
            
            // CRITICAL: Use screen.frame (NOT visibleFrame) to go above menu bar
            let screenFrame = screen.frame
            
            // Center X
            let xPos = screenFrame.origin.x + (screenFrame.width - windowWidth) / 2
            
            // FIXED: Position at ABSOLUTE top (above menu bar)
            // screen.frame.maxY is the top pixel of the screen
            let yPos = screenFrame.maxY - windowHeight
            
            let panelRect = NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight)
            
            let panel = NotchPanel(contentRect: panelRect, backing: .buffered, defer: false)
            
            let hostingView = NSHostingView(rootView: ContentView())
            hostingView.layer?.backgroundColor = NSColor.clear.cgColor
            
            panel.contentView = hostingView
            panel.orderFrontRegardless()
            
            self.window = panel
        }
}
