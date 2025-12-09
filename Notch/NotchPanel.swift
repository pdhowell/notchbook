import AppKit

class NotchPanel: NSPanel {
    init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: backing,
            defer: flag
        )
        
        // 1. ESSENTIAL: Enable mouse tracking
        self.acceptsMouseMovedEvents = true
        
        // 2. Float above menu bar for consistent visibility
        self.level = .statusBar + 1
        
        // 3. Full transparency
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        
        // 4. Appear on all spaces and stay put
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        
        // 5. Don't hide when clicking other apps
        self.hidesOnDeactivate = false
        
        // 6. Allow mouse events through to the window
        self.ignoresMouseEvents = false
    }
    
    // Prevent the panel from becoming key/main to avoid stealing focus
    override var canBecomeKey: Bool {
        return false
    }
    
    override var canBecomeMain: Bool {
        return false
    }
}
