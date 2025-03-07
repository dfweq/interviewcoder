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
    
    // Store the previous app for focus preservation
    private var previousApp: NSRunningApplication?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the invisible window
        setupInvisibleWindow()
        
        // Register global hotkeys
        registerHotKeys()
        registerSolutionHotKey() // Add processing hotkey
        
        // Set up local event monitor for key events within the app
        setupLocalEventMonitor()
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
        
        // Clear handlers
        hotKeyHandlers.removeAll()
    }
    
    // MARK: - Window Setup
    
    private func setupInvisibleWindow() {
        // Define a larger initial size for the window
        let contentRect = NSRect(x: 100, y: 100, width: 600, height: 500)
        window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Configure window properties
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 400, height: 300) // Set a minimum size
        
        // Create visual effect view
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
        
        // Optional: Hide standard window buttons if you want a custom look
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        
        // Show the window
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        // Enable screen capture protection
        window.sharingType = .none
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
        // Register Cmd+Enter for processing screenshots (action ID = 3)
        registerHotKey(
            keyCode: UInt32(kVK_Return),
            modifiers: UInt32(cmdKey),
            actionID: 3
        )
        
        // Store the handler
        hotKeyHandlers[3] = {
            DispatchQueue.main.async {
                let screenshots = ScreenshotManager.shared.screenshots
                let language = "python" // Ideally, get from UI state
                SolutionState.shared.processScreenshots(screenshots, language: language)
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
            self.screenshotManager.captureScreenshot(
                hideWindow: {
                    self.window.orderOut(nil)
                },
                showWindow: {
                    if self.isWindowVisible {
                        self.window.orderFrontRegardless()
                    }
                }
            )
        }
    }
    
    // MARK: - Window Movement
    
    private func moveWindowLeft() {
        var frame = window.frame
        frame.origin.x -= 10
        window.setFrame(frame, display: true, animate: true)
    }
    
    private func moveWindowRight() {
        var frame = window.frame
        frame.origin.x += 10
        window.setFrame(frame, display: true, animate: true)
    }
    
    private func moveWindowUp() {
        var frame = window.frame
        frame.origin.y += 10
        window.setFrame(frame, display: true, animate: true)
    }
    
    private func moveWindowDown() {
        var frame = window.frame
        frame.origin.y -= 10
        window.setFrame(frame, display: true, animate: true)
    }
}
