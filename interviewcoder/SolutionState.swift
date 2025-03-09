import Foundation
import SwiftUI

@MainActor
// This class will manage the state of the solution process
class SolutionState: ObservableObject {
    @Published var isProcessing = false
    @Published var solution: SolutionResult?
    @Published var errorMessage: String?
    @Published var isDebugMode = false
    @Published var debugSolution: SolutionResult?
    
    static let shared = SolutionState()
    
    private init() {}
    
    func processScreenshots(_ screenshots: [ScreenshotManager.Screenshot], language: String = "python") {
        guard let firstScreenshot = screenshots.first else {
            self.errorMessage = "No screenshots to process"
            return
        }
        
        // Check if API key is set
        if !APIKeyManager.hasAPIKey() {
            self.errorMessage = "OpenAI API key not set. Please set your API key and try again."
            return
        }
        
        self.isProcessing = true
        self.errorMessage = nil
        
        // Notify that processing has started
        NotificationCenter.default.post(
            name: Notification.Name("SolutionReceived"),
            object: nil
        )
        
        OpenAIService.shared.analyzeScreenshot(image: firstScreenshot.image, language: language) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isProcessing = false
                
                switch result {
                case .success(let solution):
                    self.solution = solution
                    self.errorMessage = nil
                    
                case .failure(let error):
                    if let openAIError = error as? OpenAIError, openAIError == OpenAIError.invalidAPIKey {
                        self.errorMessage = "Invalid API key. Please update your OpenAI API key."
                    } else {
                        self.errorMessage = "Error: \(error.localizedDescription)"
                    }
                    self.solution = nil
                }
                
                // Notify that the solution has been updated
                NotificationCenter.default.post(
                    name: Notification.Name("SolutionUpdated"),
                    object: nil
                )
            }
        }
    }
    
    func processDebugScreenshots(originalScreenshots: [ScreenshotManager.Screenshot], extraScreenshots: [ScreenshotManager.Screenshot], language: String = "python") {
        guard !originalScreenshots.isEmpty, !extraScreenshots.isEmpty else {
            self.errorMessage = "Missing screenshots for debug"
            return
        }
        
        // Check if API key is set
        if !APIKeyManager.hasAPIKey() {
            self.errorMessage = "OpenAI API key not set. Please set your API key and try again."
            return
        }
        
        self.isProcessing = true
        self.errorMessage = nil
        self.isDebugMode = true
        
        // Notify that processing has started
        NotificationCenter.default.post(
            name: Notification.Name("SolutionReceived"),
            object: nil
        )
        
        // Get original images
        let originalImages = originalScreenshots.map { $0.image }
        
        // Get the last extra screenshot as the newest one
        guard let newScreenshot = extraScreenshots.last?.image else {
            self.errorMessage = "No new screenshot for debugging"
            self.isProcessing = false
            return
        }
        
        OpenAIService.shared.debugWithExtraScreenshot(originalScreenshots: originalImages, newScreenshot: newScreenshot, language: language) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isProcessing = false
                
                switch result {
                case .success(let solution):
                    self.debugSolution = solution
                    self.errorMessage = nil
                    
                case .failure(let error):
                    if let openAIError = error as? OpenAIError, openAIError == OpenAIError.invalidAPIKey {
                        self.errorMessage = "Invalid API key. Please update your OpenAI API key."
                    } else {
                        self.errorMessage = "Debug Error: \(error.localizedDescription)"
                    }
                    self.debugSolution = nil
                }
                
                // Notify that the solution has been updated
                NotificationCenter.default.post(
                    name: Notification.Name("SolutionUpdated"),
                    object: nil
                )
            }
        }
    }
    
    func regenerateSolution(language: String = "python") {
        // Use existing screenshots to regenerate solution
        guard let screenshots = ScreenshotManager.shared.screenshots.first else {
            self.errorMessage = "No screenshots to process"
            return
        }
        
        // Check if API key is set
        if !APIKeyManager.hasAPIKey() {
            self.errorMessage = "OpenAI API key not set. Please set your API key and try again."
            return
        }
        
        // Clear existing solution
        self.solution = nil
        self.debugSolution = nil
        
        // Process the screenshots again
        self.isProcessing = true
        self.errorMessage = nil
        
        // Notify that processing has started
        NotificationCenter.default.post(
            name: Notification.Name("SolutionReceived"),
            object: nil
        )
        
        OpenAIService.shared.analyzeScreenshot(image: screenshots.image, language: language) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isProcessing = false
                
                switch result {
                case .success(let solution):
                    self.solution = solution
                    self.errorMessage = nil
                    
                case .failure(let error):
                    if let openAIError = error as? OpenAIError, openAIError == OpenAIError.invalidAPIKey {
                        self.errorMessage = "Invalid API key. Please update your OpenAI API key."
                    } else {
                        self.errorMessage = "Error: \(error.localizedDescription)"
                    }
                    self.solution = nil
                }
                
                // Notify that the solution has been updated
                NotificationCenter.default.post(
                    name: Notification.Name("SolutionUpdated"),
                    object: nil
                )
            }
        }
    }
    
    func resetState() {
        self.solution = nil
        self.debugSolution = nil
        self.errorMessage = nil
        self.isProcessing = false
        self.isDebugMode = false
    }
}
