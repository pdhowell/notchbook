import AppKit
import SwiftUI

class NotchPanel: NSPanel {
    private var hostingController: NSHostingController<ContentView>?
    private var globalDragMonitor: Any?
    private var globalUpMonitor: Any?
    private var temporarilyEnabledForDrag = false
    private var shouldIgnoreClicks = true  // Track if we should ignore clicks
    
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
        // DO NOT set ignoresMouseEvents here - we'll handle it manually
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

        // Observe collapse/expand notifications from SwiftUI content
        NotificationCenter.default.addObserver(self, selector: #selector(handleToggleMouseEvents(_:)), name: Notification.Name("NotchPanelToggleMouseEvents"), object: nil)

        // Add global event monitors to temporarily enable the panel when a drag is occurring
        // This allows drag-and-drop onto the notch while keeping it click-through when collapsed.
        globalDragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseDown]) { [weak self] event in
            guard let self = self else { return }
            let mousePoint = NSEvent.mouseLocation // screen coords
            DispatchQueue.main.async {
                // If mouse is over our panel and the panel is currently ignoring mouse events,
                // temporarily enable it so it can accept drag/drop.
                if self.frame.contains(mousePoint) && (self.shouldIgnoreClicks || self.ignoresMouseEvents) {
                    self.temporarilyEnabledForDrag = true
                    self.updateIgnoresMouseEvents()
                }
            }
        }

        globalUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if self.temporarilyEnabledForDrag {
                    self.temporarilyEnabledForDrag = false
                    self.updateIgnoresMouseEvents()
                }
            }
        }

        // Initialize ignoresMouseEvents according to current logical state
        updateIgnoresMouseEvents()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if let drag = globalDragMonitor { NSEvent.removeMonitor(drag) }
        if let up = globalUpMonitor { NSEvent.removeMonitor(up) }
    }

    @objc private func handleToggleMouseEvents(_ notification: Notification) {
        guard let info = notification.userInfo as? [String: Any], let ignore = info["ignore"] as? Bool else { return }
        DispatchQueue.main.async {
            self.shouldIgnoreClicks = ignore
            // Update the actual ignoresMouseEvents state taking into account drag temp state
            self.updateIgnoresMouseEvents()
        }
    }

    private func updateIgnoresMouseEvents() {
        // If we should ignore clicks and we're not temporarily enabled for drag,
        // set ignoresMouseEvents to true so underlying apps receive clicks.
        var ignore = shouldIgnoreClicks && !temporarilyEnabledForDrag

        // Special-case: if the panel is positioned at the very top of the screen
        // (just under the system notch / menu bar), macOS may prevent global drag
        // monitors from firing reliably; in that case we should NOT enable
        // passthrough (ignoresMouseEvents) so drag-and-drop onto the panel works.
        if let screen = self.screen {
            // Compare panel top to screen visible top (visibleFrame.maxY). If the
            // panel's top is within a few pixels of the visible top, consider it
            // 'at the top edge'.
            let panelTop = self.frame.maxY
            let topY = screen.visibleFrame.maxY
            let distance = abs(panelTop - topY)
            if distance <= 12 {
                // Don't ignore clicks when the panel sits at the top edge.
                ignore = false
            }
        }

        if self.ignoresMouseEvents != ignore {
            self.ignoresMouseEvents = ignore
        }
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
    
    // MARK: - Event Handling Override
    
    override func sendEvent(_ event: NSEvent) {
        // Always allow drag and drop events through
        if event.type == .leftMouseDragged ||
           event.type == .rightMouseDragged ||
           event.type == .otherMouseDragged {
            super.sendEvent(event)
            return
        }
        
        // If we should ignore clicks, only block click events, not hover or drag
        if shouldIgnoreClicks {
            switch event.type {
            case .leftMouseDown, .rightMouseDown, .otherMouseDown,
                 .leftMouseUp, .rightMouseUp, .otherMouseUp:
                // Block these click events when collapsed
                return
            default:
                // Allow everything else (hover, drag, etc.)
                super.sendEvent(event)
            }
        } else {
            // When expanded or settings shown, allow all events
            super.sendEvent(event)
        }
    }
    
    // MARK: - Overrides
    
    override var canBecomeKey: Bool {
        return false
    }
    
    override var canBecomeMain: Bool {
        return false
    }
    
    func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}
