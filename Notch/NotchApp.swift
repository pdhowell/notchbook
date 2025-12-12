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

//     func setupWindow() {
//         guard let screen = NSScreen.main else { return }

//         // Window dimensions
//         let windowWidth: CGFloat = 1000
//         let windowHeight: CGFloat = 600

//         let fullFrame = screen.frame
        
//         // Center horizontally
//         let xPos = fullFrame.origin.x + (fullFrame.width - windowWidth) / 2
        
//         // Position at absolute top: in macOS coords, top = maxY
//         // We want window top edge at screen top edge
//         // Window's top = origin.y + height, so: origin.y + height = fullFrame.maxY

// //         let menuBarHeight = NSStatusBar.system.thickness
// // let yPos = fullFrame.maxY - NSStatusBar.system.thickness - windowHeight

// // let menuBarHeight = NSStatusBar.system.thickness
// // let yPos = fullFrame.maxY - menuBarHeight - windowHeight

// // let visualPadding: CGFloat = -8   // try -6 to -12 depending on your screen
// // let yPos = fullFrame.maxY - NSStatusBar.system.thickness - windowHeight + visualPadding

// let menuBarHeight = NSStatusBar.system.thickness
// let desiredGap: CGFloat = 12     // tweak between 10–14 to match GIF perfectly

// let yPos = fullFrame.maxY - menuBarHeight - windowHeight - desiredGap




//         // let yPos = fullFrame.maxY - windowHeight

//         let panelRect = NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight)
        
//         let panel = NotchPanel(contentRect: panelRect, backing: .buffered, defer: false)
        
//         // CRITICAL ADDITIONS for top positioning
//         // panel.level = .screenSaver  // Higher than .floating to go above menu bar
//         // panel.collectionBehavior.insert(.fullScreenPrimary)  // Allow it in the menu bar area
        

// //         panel.level = .statusBar     // slightly above normal windows, below menu bar
// // panel.collectionBehavior = [.canJoinAllSpaces, .stationary]

// panel.level = .statusBar     // below menu bar, above normal windows
// panel.collectionBehavior = [.canJoinAllSpaces, .stationary]



//         let hostingView = NSHostingView(rootView: ContentView())
//         hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        
//         panel.contentView = hostingView
//         panel.orderFrontRegardless()
        
//         self.window = panel
//     }

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

