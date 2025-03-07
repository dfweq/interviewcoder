import Cocoa
import SwiftUI
import Carbon
import ScreenCaptureKit

// Store event handlers globally to avoid context capturing
var hotKeyHandlers: [UInt32: () -> Void] = [:]

// Global C function for handling hotkey events
func hotKeyEventHandler(_ nextHandler: EventHandlerCallRef?, _ theEvent: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    var hotKeyID = EventHotKeyID()
    let error = GetEventParameter(
        theEvent,
        UInt32(kEventParamDirectObject),
        UInt32(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    
    if error == noErr {
        if let handler = hotKeyHandlers[hotKeyID.id] {
            handler()
        }
    }
    
    return noErr
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow!
    var isWindowVisible = true
    private var localEventMonitor: Any?
    
    // Store hotkey references to prevent deallocation
    private var toggleVisibilityHotKey: EventHotKeyRef?
    private var screenshotHotKey: EventHotKeyRef?
    private var processHotKey: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    
    // Screenshot manager reference
    private let screenshotManager = ScreenshotManager.shared
    private let solutionState = SolutionState.shared
    
    // Store the previous app for focus preservation
    private var previousApp: NSRunningApplication?
    
    // Window states
    private let compactSize = NSSize(width: 320, height: 150)
    private let expandedSize = NSSize(width: 700, height: 600)
    private var isExpanded = false
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the window with a minimal size initially
        setupWindow()
        
        // Register global hotkeys
        registerHotKeys()
        registerSolutionHotKey()
        
        // Set up local event monitor for key events within the app
        setupLocalEventMonitor()
        
        // Observe solution state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSolutionReceived),
            name: Notification.Name("SolutionReceived"),
            object: nil
        )
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Unregister hotkeys
        if let hotKeyRef = toggleVisibilityHotKey {
            UnregisterEventHotKey(hotKeyRef)
        }
        
        if let hotKeyRef = screenshotHotKey {
            UnregisterEventHotKey(hotKeyRef)
        }
        
        if let hotKeyRef = processHotKey {
            UnregisterEventHotKey(hotKeyRef)
        }
        
        // Remove event handler
        if let eventHandler = eventHandlerRef {
            RemoveEventHandler(eventHandler)
        }
        
        // Remove event monitor
        if let localEventMonitor = localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
        }
        
        // Remove notifications
        NotificationCenter.default.removeObserver(self)
        
        // Clear handlers
        hotKeyHandlers.removeAll()
    }
    
    // MARK: - Window Setup
    
    private func setupWindow() {
        // Start with a small window
        let contentRect = NSRect(origin: .zero, size: compactSize)
        window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Configure window properties
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = NSColor.black.withAlphaComponent(0.5) // More transparent
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.titleVisibility = .hidden
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        
        // Create visual effect view for the background
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .hudWindow
        visualEffectView.state = .active
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 12
        visualEffectView.layer?.masksToBounds = true
        
        // Set up the content view with SwiftUI
        let contentView = NSHostingView(rootView: MainContentView())
        visualEffectView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor)
        ])
        
        window.contentView = visualEffectView
        
        // Position near the top-right of the screen
        positionWindowInCorner()
        
        window.makeKeyAndOrderFront(nil)
        
        // Enable screen capture protection
        window.sharingType = .none
    }
    
    // Position window in the top-right corner of the screen
    private func positionWindowInCorner() {
        if let screenFrame = NSScreen.main?.visibleFrame {
            var windowFrame = window.frame
            
            // Position in top-right with some padding
            windowFrame.origin.x = screenFrame.maxX - windowFrame.width - 20
            windowFrame.origin.y = screenFrame.maxY - windowFrame.height - 40
            
            window.setFrame(windowFrame, display: true)
        }
    }
    
    // MARK: - Window Resizing
    
    @objc func handleSolutionReceived() {
        expandWindow()
    }
    
    private func expandWindow() {
        // Only expand if we're currently in compact mode
        if !isExpanded {
            isExpanded = true
            resizeWindow(to: expandedSize)
        }
    }
    
    private func compactWindow() {
        // Only compact if we're currently in expanded mode
        if isExpanded {
            isExpanded = false
            resizeWindow(to: compactSize)
        }
    }
    
    private func resizeWindow(to size: NSSize) {
        // Remember current position
        let currentOrigin = window.frame.origin
        
        // Calculate new frame
        var newFrame = NSRect(origin: currentOrigin, size: size)
        
        // Ensure the window stays on screen
        if let screenFrame = NSScreen.main?.visibleFrame {
            if newFrame.maxX > screenFrame.maxX {
                newFrame.origin.x = screenFrame.maxX - newFrame.width - 20
            }
            if newFrame.maxY > screenFrame.maxY {
                newFrame.origin.y = screenFrame.maxY - newFrame.height - 40
            }
        }
        
        // Animate the resize
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            window.animator().setFrame(newFrame, display: true)
        }
    }
    
    // MARK: - Hotkey Registration
    
    private func registerHotKeys() {
        // Install a single event handler for all hotkeys
        let eventSpec = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))]
        
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            eventSpec,
            nil,
            &eventHandlerRef
        )
        
        // Register Cmd+B for toggling window visibility (action ID = 1)
        registerHotKey(
            keyCode: UInt32(kVK_ANSI_B),
            modifiers: UInt32(cmdKey),
            actionID: 1
        )
        
        // Register Cmd+H for taking screenshots (action ID = 2)
        registerHotKey(
            keyCode: UInt32(kVK_ANSI_H),
            modifiers: UInt32(cmdKey),
            actionID: 2
        )
        
        // Store the handlers for these hotkeys
        hotKeyHandlers[1] = { [weak self] in
            self?.toggleWindowPreservingFocus()
        }
        
        hotKeyHandlers[2] = { [weak self] in
            self?.takeScreenshot()
        }
    }
    
    private func registerSolutionHotKey() {
        // Register Cmd+Return for processing screenshots (action ID = 3)
        registerHotKey(
            keyCode: UInt32(kVK_Return),
            modifiers: UInt32(cmdKey),
            actionID: 3
        )
        
        // Store the handler
        hotKeyHandlers[3] = { [weak self] in
            DispatchQueue.main.async {
                let screenshots = ScreenshotManager.shared.screenshots
                let language = "python" // Default language
                SolutionState.shared.processScreenshots(screenshots, language: language)
                
                // Expand window when processing starts
                self?.expandWindow()
            }
        }
    }
    
    private func registerHotKey(keyCode: UInt32, modifiers: UInt32, actionID: UInt32) {
        var hotKeyRef: EventHotKeyRef?
        var gMyHotKeyID = EventHotKeyID()
        
        gMyHotKeyID.signature = OSType(actionID)
        gMyHotKeyID.id = UInt32(actionID)
        
        // Register the hotkey
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            gMyHotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr {
            if actionID == 1 {
                toggleVisibilityHotKey = hotKeyRef
            } else if actionID == 2 {
                screenshotHotKey = hotKeyRef
            } else if actionID == 3 {
                processHotKey = hotKeyRef
            }
        } else {
            print("Failed to register hotkey: \(status)")
        }
    }
    
    // MARK: - Event Monitoring
    
    private func setupLocalEventMonitor() {
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if event.modifierFlags.contains(.command) {
                switch event.keyCode {
                case UInt16(kVK_LeftArrow):
                    self?.moveWindowLeft()
                    return nil
                case UInt16(kVK_RightArrow):
                    self?.moveWindowRight()
                    return nil
                case UInt16(kVK_UpArrow):
                    self?.moveWindowUp()
                    return nil
                case UInt16(kVK_DownArrow):
                    self?.moveWindowDown()
                    return nil
                case UInt16(kVK_ANSI_Q):
                    if event.modifierFlags.contains(.command) {
                        NSApp.terminate(nil)
                    }
                case UInt16(kVK_ANSI_0): // Cmd+0 to reset to compact size
                    self?.compactWindow()
                    return nil
                default:
                    break
                }
            }
            return event
        }
    }
    
    // MARK: - Hotkey Actions
    
    func toggleWindowPreservingFocus() {
        // Store the currently active application
        previousApp = NSWorkspace.shared.frontmostApplication
        
        // Toggle visibility
        isWindowVisible.toggle()
        if isWindowVisible {
            window.orderFrontRegardless()
            window.makeKey()
        } else {
            window.orderOut(nil)
            // Restore focus to the previous app
            if let app = previousApp {
                app.activate(options: .activateIgnoringOtherApps)
            }
        }
    }
    
    func takeScreenshot() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Make sure the window is hidden before taking the screenshot
            let wasVisible = self.isWindowVisible
            self.window.orderOut(nil)
            
            // Wait a short time to ensure the window is fully hidden
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.screenshotManager.captureScreenshot(
                    hideWindow: { /* Window is already hidden */ },
                    showWindow: {
                        // Only show the window if it was visible before
                        if wasVisible {
                            self.window.orderFrontRegardless()
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Window Movement
    
    private func moveWindowLeft() {
        var frame = window.frame
        frame.origin.x -= 20
        window.setFrame(frame, display: true, animate: false)
    }
    
    private func moveWindowRight() {
        var frame = window.frame
        frame.origin.x += 20
        window.setFrame(frame, display: true, animate: false)
    }
    
    private func moveWindowUp() {
        var frame = window.frame
        frame.origin.y += 20
        window.setFrame(frame, display: true, animate: false)
    }
    
    private func moveWindowDown() {
        var frame = window.frame
        frame.origin.y -= 20
        window.setFrame(frame, display: true, animate: false)
    }
}
