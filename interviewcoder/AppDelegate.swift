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
    private var resetHotKey: EventHotKeyRef?
    private var regenerateHotKey: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    
    // Screenshot manager reference - initialized in applicationDidFinishLaunching
    private var screenshotManager: ScreenshotManager!
    private var solutionState: SolutionState!
    
    // Store the previous app for focus preservation
    private var previousApp: NSRunningApplication?
    
    // Window states
    private let compactSize = NSSize(width: 750, height: 80)
    private let expandedSize = NSSize(width: 700, height: 600)
    private var isExpanded = false
    
    // Constants for window positioning
    private let screenEdgeMargin: CGFloat = 20
    private let minimumVisiblePortion: CGFloat = 100
    
    // New method for programmatic app initialization
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.activate(ignoringOtherApps: true)
        app.run()
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Initialize main actor confined objects here
        self.screenshotManager = ScreenshotManager.shared
        self.solutionState = SolutionState.shared
        
        // Ensure app is active
        NSApp.activate(ignoringOtherApps: true)
        
        // Create the window with a minimal size initially
        setupWindow()
        
        // Position window in the top right corner initially
        positionWindowInTopRight()
        
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
        
        // Observe reset requests
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleResetToCompact),
            name: Notification.Name("ResetToCompact"),
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
        
        if let hotKeyRef = resetHotKey {
            UnregisterEventHotKey(hotKeyRef)
        }
        
        if let hotKeyRef = regenerateHotKey {
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
        
        // Create a panel instead of a window with nonactivatingPanel style
        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Set panel-specific properties
        panel.isFloatingPanel = true
        panel.worksWhenModal = true
        panel.becomesKeyOnlyIfNeeded = true
        
        // Assign the panel to our window property
        window = panel
        
        // Configure window properties
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = NSColor.black.withAlphaComponent(0.25) // More transparent (reduced from 0.5)
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
        visualEffectView.material = .windowBackground // Use modern semantic material
        visualEffectView.state = .active
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 12
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.layer?.opacity = 0.7 // Add opacity to make it more transparent

        // Force dark appearance for better readability with transparency
        visualEffectView.appearance = NSAppearance(named: .darkAqua)
        
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
        window.makeKeyAndOrderFront(nil)
        
        // Enable screen capture protection
        window.sharingType = .none
    }
    
    // Position window in the top-right corner of the screen initially
    private func positionWindowInTopRight() {
        if let screenFrame = NSScreen.main?.visibleFrame {
            var windowFrame = window.frame
            
            // Position in top-right with some padding
            windowFrame.origin.x = screenFrame.maxX - windowFrame.width - screenEdgeMargin
            windowFrame.origin.y = screenFrame.maxY - windowFrame.height - screenEdgeMargin
            
            window.setFrame(windowFrame, display: true)
        }
    }
    
    // MARK: - Window Resizing
    
    @objc func handleSolutionReceived() {
        expandWindow()
    }
    
    @objc func handleResetToCompact() {
        compactWindow()
    }
    
    private func expandWindow() {
        // Only expand if we're currently in compact mode
        if !isExpanded {
            isExpanded = true
            resizeWindowInPlace(to: expandedSize)
        }
    }
    
    private func compactWindow() {
        // Only compact if we're currently in expanded mode
        if isExpanded {
            isExpanded = false
            resizeWindowInPlace(to: compactSize)
        }
    }
    
    // Resize the window while keeping it in the same position
    private func resizeWindowInPlace(to newSize: NSSize) {
        // Get the current window frame
        let currentFrame = window.frame
        
        // Calculate center point of current window
        let centerX = currentFrame.origin.x + (currentFrame.width / 2)
        let centerY = currentFrame.origin.y + (currentFrame.height / 2)
        
        // Calculate new origin that maintains the center point
        let newOriginX = centerX - (newSize.width / 2)
        let newOriginY = centerY - (newSize.height / 2)
        
        // Create new frame with the same center point
        var newFrame = NSRect(
            x: newOriginX,
            y: newOriginY,
            width: newSize.width,
            height: newSize.height
        )
        
        // Apply safety bounds checks to ensure window is not completely off-screen
        newFrame = ensureWindowIsAccessible(frame: newFrame)
        
        // Animate the resize
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            window.animator().setFrame(newFrame, display: true)
        }
    }
    
    // Ensure window is accessible and not completely off-screen
    private func ensureWindowIsAccessible(frame: NSRect) -> NSRect {
        guard let screenFrame = NSScreen.main?.visibleFrame else {
            return frame
        }
        
        var adjustedFrame = frame
        
        // Make sure at least minimumVisiblePortion is visible on each edge
        
        // Right edge
        if adjustedFrame.origin.x + adjustedFrame.width < screenFrame.origin.x + minimumVisiblePortion {
            adjustedFrame.origin.x = screenFrame.origin.x + minimumVisiblePortion - adjustedFrame.width
        }
        
        // Left edge
        if adjustedFrame.origin.x > screenFrame.origin.x + screenFrame.width - minimumVisiblePortion {
            adjustedFrame.origin.x = screenFrame.origin.x + screenFrame.width - minimumVisiblePortion
        }
        
        // Bottom edge
        if adjustedFrame.origin.y + adjustedFrame.height < screenFrame.origin.y + minimumVisiblePortion {
            adjustedFrame.origin.y = screenFrame.origin.y + minimumVisiblePortion - adjustedFrame.height
        }
        
        // Top edge
        if adjustedFrame.origin.y > screenFrame.origin.y + screenFrame.height - minimumVisiblePortion {
            adjustedFrame.origin.y = screenFrame.origin.y + screenFrame.height - minimumVisiblePortion
        }
        
        return adjustedFrame
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
        
        // Register Cmd+R for clearing all screenshots (action ID = 4)
        registerHotKey(
            keyCode: UInt32(kVK_ANSI_R),
            modifiers: UInt32(cmdKey),
            actionID: 4
        )
        
        // Register Cmd+G for regenerating solution (action ID = 5)
        registerHotKey(
            keyCode: UInt32(kVK_ANSI_G),
            modifiers: UInt32(cmdKey),
            actionID: 5
        )
        
        // Store the handlers for these hotkeys
        hotKeyHandlers[1] = { [weak self] in
            self?.toggleWindowPreservingFocus()
        }
        
        hotKeyHandlers[2] = { [weak self] in
            self?.takeScreenshot()
        }
        
        hotKeyHandlers[4] = { [weak self] in
            DispatchQueue.main.async {
                self?.screenshotManager.clearQueue()
                self?.solutionState.resetState()
                
                // Return to compact size (in place)
                self?.compactWindow()
                NotificationCenter.default.post(
                    name: Notification.Name("ResetToCompact"),
                    object: nil
                )
            }
        }
        
        hotKeyHandlers[5] = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self, !self.screenshotManager.screenshots.isEmpty else { return }
                let language = "python" // Default language
                self.solutionState.regenerateSolution(language: language)
            }
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
                guard let self = self else { return }
                let screenshots = self.screenshotManager.screenshots
                if !screenshots.isEmpty {
                    let language = "python" // Default language
                    self.solutionState.processScreenshots(screenshots, language: language)
                    
                    // Expand window in place when processing starts
                    self.expandWindow()
                }
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
            switch actionID {
            case 1:
                toggleVisibilityHotKey = hotKeyRef
            case 2:
                screenshotHotKey = hotKeyRef
            case 3:
                processHotKey = hotKeyRef
            case 4:
                resetHotKey = hotKeyRef
            case 5:
                regenerateHotKey = hotKeyRef
            default:
                break
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
            // Don't make the window key as it would activate the app
        } else {
            window.orderOut(nil)
        }
        
        // Always restore focus to the previous app
        if let app = previousApp {
            app.activate(options: [])
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
                            
                            // Make sure we restore focus to the previous app
                            if let app = self.previousApp {
                                app.activate(options: [])
                            }
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
        
        // Apply bounds check
        frame = ensureWindowIsAccessible(frame: frame)
        window.setFrame(frame, display: true, animate: false)
    }
    
    private func moveWindowRight() {
        var frame = window.frame
        frame.origin.x += 20
        
        // Apply bounds check
        frame = ensureWindowIsAccessible(frame: frame)
        window.setFrame(frame, display: true, animate: false)
    }
    
    private func moveWindowUp() {
        var frame = window.frame
        frame.origin.y += 20
        
        // Apply bounds check
        frame = ensureWindowIsAccessible(frame: frame)
        window.setFrame(frame, display: true, animate: false)
    }
    
    private func moveWindowDown() {
        var frame = window.frame
        frame.origin.y -= 20
        
        // Apply bounds check
        frame = ensureWindowIsAccessible(frame: frame)
        window.setFrame(frame, display: true, animate: false)
    }
}
