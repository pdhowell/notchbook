import AppKit
import SwiftUI

class NotchPanel: NSPanel {
    private var hostingController: NSHostingController<ContentView>?
    
    init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: backing,
            defer: flag
        )
        
        // 1. Keep window alive
        self.isReleasedWhenClosed = false
        
        // 2. Float above everything
        self.level = .floating
        
        // 3. Setup behavior
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        
        // 4. Transparency
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        
        // 5. Allow interaction
        self.acceptsMouseMovedEvents = true
        self.ignoresMouseEvents = false
        
        // 6. Lock Window Position (This replaces the need for mouseDragged)
        self.isMovable = false
        
        // 7. Remove window chrome
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
        
        setupContentView()
    }
    
    private func setupContentView() {
        let contentView = ContentView()
        let hostingController = NSHostingController(rootView: contentView)
        
        // Disable auto-resizing constraints so we can control the frame
        hostingController.sizingOptions = []
        
        let view = hostingController.view
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        
        self.contentView = view
        self.hostingController = hostingController
    }
    
    // MARK: - Overrides
    
    override var canBecomeKey: Bool {
        return false
    }
    
    override var canBecomeMain: Bool {
        return false
    }
    
    // Some SDKs may not declare this as overridable on NSPanel/NSWindow;
    // provide the implementation without 'override' to avoid compile errors.
    func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    // NOTE: 'mouseDragged' has been removed.
    // 'self.isMovable = false' in init() handles locking the window automatically.
}


