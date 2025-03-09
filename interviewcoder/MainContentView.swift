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
            
            VStack(spacing: 8) {
                // Show different views based on state
                if solutionState.solution != nil || solutionState.debugSolution != nil || solutionState.isProcessing {
                    // Expanded view with results
                    HStack {
                        Text("Interview Coder")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(.bottom, 4)
                    
                    expandedView
                } else {
                    // Compact view with just instructions and title in a horizontal bar
                    HStack {
                        Text("Interview Coder")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false) // Prevent title truncation
                            .layoutPriority(1) // Give title higher priority
                        
                        Spacer()
                        
                        // Compact view with just instructions
                        compactView
                    }
                }
            }
            .padding(10)
        }
    }
    
    // Compact view with minimal instructions in a single line
    private var compactView: some View {
        HStack(spacing: 10) {
            // Hotkey pills in single line without scrolling
            CompactKeyPill(key: "Cmd+H", action: "Screenshot")
            CompactKeyPill(key: "Cmd+B", action: "Toggle")
            CompactKeyPill(key: "Cmd+Return", action: "Process")
            
            // Only show Reset hotkey if there are screenshots
            if !screenshotManager.screenshots.isEmpty {
                CompactKeyPill(key: "Cmd+R", action: "Reset")
            }
            
            // Only show Retry hotkey if there's a solution to retry
            if solutionState.solution != nil || solutionState.debugSolution != nil {
                CompactKeyPill(key: "Cmd+G", action: "Retry")
            }
            
            // Always show the divider and count when there are screenshots
            if !screenshotManager.screenshots.isEmpty {
                // Divider for screenshots count
                Divider()
                    .background(Color.white.opacity(0.3))
                    .frame(height: 16)
                
                // Screenshot count always visible
                Text("\(screenshotManager.screenshots.count) \(screenshotManager.screenshots.count == 1 ? "shot" : "shots")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.leading, 4)
                    .padding(.trailing, 6)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.black.opacity(0.2))
        .cornerRadius(6)
    }
    
    // Top control bar
    private var expandedControlBar: some View {
        HStack(spacing: 10) {
            // Instructions in a horizontal layout, no scrolling
            Text("Cmd+H: Screenshot")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(4)
            
            Text("Cmd+B: Toggle")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(4)
            
            // Only show Reset instruction if there are screenshots
            if !screenshotManager.screenshots.isEmpty {
                Text("Cmd+R: Reset")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(4)
            }
            
            // Only show Retry instruction if there's a solution to retry
            if solutionState.solution != nil || solutionState.debugSolution != nil {
                Text("Cmd+G: Retry")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(4)
            }
            
            Spacer()
        }
    }
    
    // Expanded view with results
    private var expandedView: some View {
        VStack(spacing: 16) {
            // Top control bar
            expandedControlBar
            
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
    
    private func regenerateSolution() {
        solutionState.regenerateSolution(language: selectedLanguage)
    }
}

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
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false) // Never truncate horizontally
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.gray.opacity(0.3))
            .cornerRadius(4)
    }
}

// SolutionView with improved font size and spacing
struct SolutionView: View {
    let solution: SolutionResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let problemStatement = solution.problem_statement {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Problem Statement")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text(problemStatement)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(4)
                }
                .padding(14)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
            
            if let thoughts = solution.thoughts, !thoughts.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Approach")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    ForEach(thoughts, id: \.self) { thought in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundColor(.blue)
                                .padding(.top, 6)
                            Text(thought)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(4)
                        }
                    }
                }
                .padding(14)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
            
            if let code = solution.code {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Solution")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    
                    ScrollView([.horizontal, .vertical]) {
                        Text(code)
                            .font(.system(size: 15, design: .monospaced))
                            .foregroundColor(.green)
                            .padding(12)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .lineSpacing(6)
                    }
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(6)
                    .frame(height: min(CGFloat(code.components(separatedBy: "\n").count) * 24 + 24, 350))
                }
                .padding(14)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
            
            if let timeComplexity = solution.time_complexity, let spaceComplexity = solution.space_complexity {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Complexity Analysis")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    HStack {
                        Text("Time: ")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        Text(timeComplexity)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.vertical, 2)
                    
                    HStack {
                        Text("Space: ")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        Text(spaceComplexity)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.vertical, 2)
                }
                .padding(14)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
        }
        .padding(.vertical, 10)
    }
}

struct SolutionDebugView: View {
    let solution: SolutionResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let thoughts = solution.thoughts, !thoughts.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("What I Changed")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    ForEach(thoughts, id: \.self) { thought in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundColor(.blue)
                                .padding(.top, 6)
                            Text(thought)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(4)
                        }
                    }
                }
                .padding(14)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
            
            if let code = solution.new_code {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Improved Solution")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    
                    ScrollView([.horizontal, .vertical]) {
                        Text(code)
                            .font(.system(size: 15, design: .monospaced))
                            .foregroundColor(.green)
                            .padding(12)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .lineSpacing(6)
                    }
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(6)
                    .frame(height: min(CGFloat(code.components(separatedBy: "\n").count) * 24 + 24, 350))
                }
                .padding(14)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
            
            if let timeComplexity = solution.time_complexity, let spaceComplexity = solution.space_complexity {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Complexity Analysis")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    HStack {
                        Text("Time: ")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        Text(timeComplexity)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.vertical, 2)
                    
                    HStack {
                        Text("Space: ")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        Text(spaceComplexity)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.vertical, 2)
                }
                .padding(14)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
        }
        .padding(.vertical, 10)
    }
}
