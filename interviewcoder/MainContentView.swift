import SwiftUI

struct MainContentView: View {
    @ObservedObject private var screenshotManager = ScreenshotManager.shared
    @ObservedObject private var solutionState = SolutionState.shared
    @State private var selectedLanguage = "python"
    
    let languages = ["python", "javascript", "java", "c++", "go", "ruby", "swift"]
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.01) // Nearly transparent
            
            VStack(spacing: 12) {
                // Title
                Text("Interview Coder")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                // Show different views based on state
                if solutionState.solution != nil || solutionState.debugSolution != nil || solutionState.isProcessing {
                    // Expanded view with results
                    expandedView
                } else {
                    // Compact view with just instructions
                    compactView
                }
            }
            .padding(16)
        }
    }
    
    // Compact view with minimal instructions in a single line
    private var compactView: some View {
        HStack(spacing: 8) {
            // Hotkey pills in single line
            Group {
                CompactKeyPill(key: "Cmd+H", action: "Screenshot")
                CompactKeyPill(key: "Cmd+B", action: "Toggle")
                CompactKeyPill(key: "Cmd+Return", action: "Process")
                CompactKeyPill(key: "Cmd+Arrow", action: "Move")
            }
            
            // Divider if screenshots exist
            if !screenshotManager.screenshots.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.3))
                    .frame(height: 16)
                
                // Screenshot count
                Text("\(screenshotManager.screenshots.count) \(screenshotManager.screenshots.count == 1 ? "shot" : "shots")")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                
                // Language picker - compact version
                Picker("", selection: $selectedLanguage) {
                    ForEach(languages, id: \.self) { language in
                        Text(language).tag(language)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 80)
                .labelsHidden()
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(6)
    }
    
    // Expanded view with results
    private var expandedView: some View {
        VStack(spacing: 16) {
            // Top control bar
            HStack {
                // Instructions in a compact horizontal layout
                HStack(spacing: 12) {
                    Text("Cmd+H")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(4)
                    
                    Text("Cmd+B")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(4)
                        
                    Text("Cmd+0: Compact")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                // Language picker
                if !screenshotManager.screenshots.isEmpty {
                    HStack(spacing: 8) {
                        Text("Language:")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Picker("", selection: $selectedLanguage) {
                            ForEach(languages, id: \.self) { language in
                                Text(language).tag(language)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 100)
                        .labelsHidden()
                        
                        Button(action: {
                            processScreenshots()
                        }) {
                            Text("Process")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.6))
                                .cornerRadius(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // Screenshot queue (compact version)
            if !screenshotManager.screenshots.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Screenshots")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(screenshotManager.screenshots.indices, id: \.self) { index in
                                ScreenshotThumbnailView(
                                    thumbnail: screenshotManager.screenshots[index].thumbnail,
                                    onDelete: {
                                        screenshotManager.removeScreenshot(at: index)
                                    }
                                )
                            }
                        }
                    }
                    .frame(height: 80)
                }
                .padding(10)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
            
            // Main content area
            if solutionState.isProcessing {
                VStack {
                    Spacer()
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.0)
                        .frame(width: 40, height: 40) // Fixed frame to avoid constraint issues
                    
                    Text("Analyzing screenshot...")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.top, 8)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = solutionState.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
            } else if solutionState.isDebugMode, let debugSolution = solutionState.debugSolution {
                ScrollView {
                    SolutionDebugView(solution: debugSolution)
                }
            } else if let solution = solutionState.solution {
                ScrollView {
                    SolutionView(solution: solution)
                }
            }
        }
    }
    
    private func processScreenshots() {
        if solutionState.isDebugMode {
            solutionState.processDebugScreenshots(
                originalScreenshots: screenshotManager.screenshots,
                extraScreenshots: screenshotManager.screenshots,
                language: selectedLanguage
            )
        } else {
            solutionState.processScreenshots(
                screenshotManager.screenshots,
                language: selectedLanguage
            )
        }
        
        // Notify that a solution is being processed
        NotificationCenter.default.post(
            name: Notification.Name("SolutionReceived"),
            object: nil
        )
    }
}

// Compact, stylized key instruction component
// Original key instruction view (for expanded mode)
struct KeyInstructionView: View {
    let key: String
    let action: String
    
    var body: some View {
        HStack(spacing: 8) {
            Text(key)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(4)
            
            Text(action)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

// Compact key pill for horizontal layout - combines key and action
struct CompactKeyPill: View {
    let key: String
    let action: String
    
    var body: some View {
        Text("\(key): \(action)")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.gray.opacity(0.3))
            .cornerRadius(4)
    }
}

// SolutionView with improved layout
struct SolutionView: View {
    let solution: SolutionResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let problemStatement = solution.problem_statement {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Problem Statement")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text(problemStatement)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
            
            if let thoughts = solution.thoughts, !thoughts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Approach")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    ForEach(thoughts, id: \.self) { thought in
                        HStack(alignment: .top) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundColor(.blue)
                                .padding(.top, 5)
                            Text(thought)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
            
            if let code = solution.code {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Solution")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    ScrollView([.horizontal, .vertical]) {
                        Text(code)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.green.opacity(0.9))
                            .padding(8)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(4)
                    .frame(height: min(CGFloat(code.components(separatedBy: "\n").count) * 18 + 16, 200))
                }
                .padding(12)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
            
            if let timeComplexity = solution.time_complexity, let spaceComplexity = solution.space_complexity {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Complexity Analysis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    HStack {
                        Text("Time: ")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        Text(timeComplexity)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    HStack {
                        Text("Space: ")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        Text(spaceComplexity)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
        }
        .padding(.vertical, 8)
    }
}

struct SolutionDebugView: View {
    let solution: SolutionResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let thoughts = solution.thoughts, !thoughts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What I Changed")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    ForEach(thoughts, id: \.self) { thought in
                        HStack(alignment: .top) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundColor(.blue)
                                .padding(.top, 5)
                            Text(thought)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
            
            if let code = solution.new_code {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Improved Solution")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    ScrollView([.horizontal, .vertical]) {
                        Text(code)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.green.opacity(0.9))
                            .padding(8)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(4)
                    .frame(height: min(CGFloat(code.components(separatedBy: "\n").count) * 18 + 16, 200))
                }
                .padding(12)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
            
            if let timeComplexity = solution.time_complexity, let spaceComplexity = solution.space_complexity {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Complexity Analysis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    HStack {
                        Text("Time: ")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        Text(timeComplexity)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    HStack {
                        Text("Space: ")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        Text(spaceComplexity)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
        }
        .padding(.vertical, 8)
    }
}

// Simple thumbnail view for screenshots
struct ScreenshotThumbnailView: View {
    let thumbnail: NSImage
    let onDelete: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 110, height: 62)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
                    .padding(4)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(width: 110, height: 62)
    }
}
