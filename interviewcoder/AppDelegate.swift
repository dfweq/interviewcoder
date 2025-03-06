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
    
    private func setupInvisibleWindow() {
        // Create window with transparent properties
        let contentRect = NSRect(x: 100, y: 100, width: 500, height: 400)
        window = NSWindow(
            contentRect: contentRect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Configure window for invisibility
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        
        // Create rounded corners and visual effect
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .hudWindow
        visualEffectView.state = .active
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 12
        visualEffectView.layer?.masksToBounds = true
        
        // Set content view controller
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
        
        // Hide standard window buttons
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        
        // Show window
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        // Enable screen capture protection
        window.sharingType = .none
    }
    
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
            }
        } else {
            print("Failed to register hotkey: \(status)")
        }
    }
    
    private func setupLocalEventMonitor() {
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            // Handle arrow keys for window movement when combined with command key
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
    
    // MARK: - Window Actions
    
    func toggleWindowPreservingFocus() {
        print("Toggling window visibility with focus preservation")
        // Store current focused app before toggling
        previousApp = NSWorkspace.shared.frontmostApplication
        
        toggleWindowVisibility()
        
        // Return focus to previous app
        if let previousApp = previousApp {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                previousApp.activate()
            }
        }
    }
    
    func toggleWindowVisibility() {
        isWindowVisible.toggle()
        
        if isWindowVisible {
            window.makeKeyAndOrderFront(nil)
            window.alphaValue = 1.0
        } else {
            window.alphaValue = 0.0
            window.orderOut(nil)
        }
    }
    
    func hideWindow() {
        window.alphaValue = 0.0
        window.orderOut(nil)
    }
    
    func showWindow() {
        window.makeKeyAndOrderFront(nil)
        window.alphaValue = 1.0
    }
    
    func takeScreenshot() {
        // Use the screenshot manager to take a screenshot
        screenshotManager.captureScreenshot(
            hideWindow: { [weak self] in self?.hideWindow() },
            showWindow: { [weak self] in self?.showWindow() }
        )
    }
    
    func moveWindowLeft() {
        guard let frame = window?.frame else { return }
        window.setFrame(NSRect(x: frame.origin.x - 20, y: frame.origin.y, width: frame.width, height: frame.height), display: true)
    }
    
    func moveWindowRight() {
        guard let frame = window?.frame else { return }
        window.setFrame(NSRect(x: frame.origin.x + 20, y: frame.origin.y, width: frame.width, height: frame.height), display: true)
    }
    
    func moveWindowUp() {
        guard let frame = window?.frame else { return }
        window.setFrame(NSRect(x: frame.origin.x, y: frame.origin.y + 20, width: frame.width, height: frame.height), display: true)
    }
    
    func moveWindowDown() {
        guard let frame = window?.frame else { return }
        window.setFrame(NSRect(x: frame.origin.x, y: frame.origin.y - 20, width: frame.width, height: frame.height), display: true)
    }
}
