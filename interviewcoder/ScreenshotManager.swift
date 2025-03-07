import Cocoa
import ScreenCaptureKit
import SwiftUI

@MainActor
/// Manages screenshots, including capture, storage, and queue management
class ScreenshotManager: ObservableObject {
    // Published properties for SwiftUI to observe
    @Published var screenshots: [Screenshot] = []
    @Published var isCapturing = false
    @Published var permissionGranted = false
    
    // Maximum number of screenshots in the queue
    private let maxScreenshots = 5
    private var captureEngine: ScreenCaptureEngine?
    
    // Singleton instance
    static let shared = ScreenshotManager()
    
    private init() {
        // Check screen capture permission
        checkPermission()
    }
    
    /// Data model for a screenshot
    struct Screenshot: Identifiable {
        let id = UUID()
        let image: NSImage
        let thumbnail: NSImage
        let timestamp: Date
        
        // Create a thumbnail from the original image
        static func createThumbnail(from image: NSImage, size: CGSize = CGSize(width: 128, height: 72)) -> NSImage {
            let thumbnail = NSImage(size: size)
            thumbnail.lockFocus()
            
            NSGraphicsContext.current?.imageInterpolation = .high
            image.draw(in: NSRect(origin: .zero, size: size),
                     from: NSRect(origin: .zero, size: image.size),
                     operation: .copy,
                     fraction: 1.0)
            
            thumbnail.unlockFocus()
            return thumbnail
        }
    }
    
    // Check and request screen capture permission
    func checkPermission() {
        Task {
            do {
                print("Checking screen capture permission")
                let _ = try await SCShareableContent.current
                
                DispatchQueue.main.async {
                    self.permissionGranted = true
                    print("Screen capture permission granted")
                }
            } catch {
                DispatchQueue.main.async {
                    self.permissionGranted = false
                    print("Screen capture permission denied: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Capture a screenshot of the entire screen
    func captureScreenshot(hideWindow: @escaping () -> Void, showWindow: @escaping () -> Void) {
        // Set capturing state
        isCapturing = true
        
        // Initialize capture engine if needed
        if captureEngine == nil {
            captureEngine = ScreenCaptureEngine()
        }
        
        // Hide the window before taking the screenshot
        hideWindow()
        
        // Wait briefly for the window to hide
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            // Capture the screen
            self.captureEngine?.captureScreen { [weak self] image in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    // Show the window after capturing
                    showWindow()
                    
                    if let image = image {
                        print("Screenshot captured successfully")
                        
                        // Create thumbnail and add to queue
                        let thumbnail = Screenshot.createThumbnail(from: image)
                        let screenshot = Screenshot(
                            image: image,
                            thumbnail: thumbnail,
                            timestamp: Date()
                        )
                        
                        self.addToQueue(screenshot)
                    } else {
                        print("Failed to capture screenshot")
                        // Could show an alert here
                    }
                    
                    self.isCapturing = false
                }
            }
        }
    }
    
    /// Add a screenshot to the queue, managing the maximum size
    private func addToQueue(_ screenshot: Screenshot) {
        // If we're at max capacity, remove the oldest screenshot
        if screenshots.count >= maxScreenshots {
            screenshots.removeFirst()
        }
        
        // Add the new screenshot
        screenshots.append(screenshot)
    }
    
    /// Remove a screenshot from the queue
    func removeScreenshot(at index: Int) {
        guard index >= 0 && index < screenshots.count else { return }
        screenshots.remove(at: index)
    }
    
    /// Remove all screenshots from the queue
    func clearQueue() {
        screenshots.removeAll()
    }
    
    /// Save a screenshot to disk (optional)
    func saveScreenshot(_ screenshot: Screenshot, to url: URL) -> Bool {
        guard let data = screenshot.image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: data),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return false
        }
        
        do {
            try pngData.write(to: url)
            return true
        } catch {
            print("Error saving screenshot: \(error)")
            return false
        }
    }
    
    // Add this method to the ScreenshotManager class
    func getImagesFromScreenshots() -> [NSImage] {
        return screenshots.map { $0.image }
    }

}

// MARK: - Screen Capture Engine

class ScreenCaptureEngine {
    private var stream: SCStream?
    private var captureCompletion: ((NSImage?) -> Void)?
    private var output: SCStreamOutput?
    private var contentFilter: SCContentFilter?
    
    func captureScreen(completion: @escaping (NSImage?) -> Void) {
        print("Starting screen capture")
        self.captureCompletion = completion
        
        // Start the capture process asynchronously
        Task {
            await startCapture()
        }
    }
    
    private func startCapture() async {
        do {
            print("Requesting screen capture content")
            // Get available screen content to capture
            let availableContent = try await SCShareableContent.current
            
            print("Available displays: \(availableContent.displays.count)")
            
            // Use only the main display for capture
            guard let mainDisplay = availableContent.displays.first else {
                print("No main display found")
                self.captureCompletion?(nil)
                return
            }
            
            print("Found main display: \(mainDisplay.width) x \(mainDisplay.height)")
            
            // Create a filter for the main display (excluding windows)
            self.contentFilter = SCContentFilter(display: mainDisplay, excludingApplications: [], exceptingWindows: [])
            
            // Create stream configuration
            let configuration = SCStreamConfiguration()
            configuration.width = Int(mainDisplay.width * 2)  // For Retina displays
            configuration.height = Int(mainDisplay.height * 2)
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
            configuration.queueDepth = 1
            
            print("Creating capture stream")
            // Create the capture stream
            let stream = SCStream(filter: self.contentFilter!, configuration: configuration, delegate: nil)
            
            // Create stream output
            self.output = CaptureStreamOutput(captureHandler: { [weak self] image in
                print("Image captured: \(image != nil ? "success" : "failed")")
                self?.captureCompletion?(image)
                
                // Stop the session after capturing one frame
                Task { @MainActor in
                    await self?.stopCapture()
                }
            })
            
            // Add stream output
            try stream.addStreamOutput(self.output!, type: .screen, sampleHandlerQueue: DispatchQueue.main)
            
            print("Starting capture stream")
            // Start the stream
            try await stream.startCapture()
            
            // Store session
            self.stream = stream
            print("Capture stream started successfully")
        } catch {
            print("Error starting screen capture: \(error.localizedDescription)")
            self.captureCompletion?(nil)
        }
    }
    
    @MainActor
    private func stopCapture() async {
        print("Stopping capture")
        do {
            if let stream = self.stream {
                try await stream.stopCapture()
                self.stream = nil
                print("Capture stopped successfully")
            }
        } catch {
            print("Error stopping capture: \(error.localizedDescription)")
        }
    }
}

// MARK: - Capture Stream Output

class CaptureStreamOutput: NSObject, SCStreamOutput {
    private let captureHandler: (NSImage?) -> Void
    
    init(captureHandler: @escaping (NSImage?) -> Void) {
        self.captureHandler = captureHandler
        super.init()
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else {
            print("Received non-screen sample buffer")
            return
        }
        
        if let frame = createImageFromSampleBuffer(sampleBuffer) {
            print("Successfully created image from sample buffer")
            captureHandler(frame)
        } else {
            print("Failed to create image from sample buffer")
            captureHandler(nil)
        }
    }
    
    private func createImageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> NSImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get image buffer from sample buffer")
            return nil
        }
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            print("Failed to create CGImage from CIImage")
            return nil
        }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
    }
    
}
