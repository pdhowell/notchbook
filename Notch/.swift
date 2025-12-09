//
//  NotchPanel 2.swift
//  Notch
//
//  Created by Srishti Tayal on 09/12/25.
//


import AppKit

class NotchPanel: NSPanel {
    init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: backing,
            defer: flag
        )
        
        // 1. ALLOW MOUSE EVENTS
        // Essential for hover detection in a non-activating window
        self.acceptsMouseMovedEvents = true
        
        // 2. STAY ON TOP
        // .floating is safer than .mainMenu for overlays
        self.level = .floating 
        
        // 3. TRANSPARENCY
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        
        // 4. BEHAVIOR ACROSS SPACES
        // .stationary helps it stay put when switching desktops
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        
        // 5. CRITICAL FOR UTILITY APPS
        // Prevents the window from vanishing when you click another app
        self.hidesOnDeactivate = false
    }
    
    // Ensure the panel doesn't try to become the "Key" window (typing focus),
    // but still allows interaction.
    override var canBecomeKey: Bool {
        return false 
    }
    
    override var canBecomeMain: Bool {
        return false
    }
}