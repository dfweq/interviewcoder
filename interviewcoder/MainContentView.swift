import SwiftUI

struct MainContentView: View {
    @ObservedObject private var screenshotManager = ScreenshotManager.shared
    @ObservedObject private var solutionState = SolutionState.shared
    @State private var selectedLanguage = "python"
    @State private var showLanguageSelector = false
    
    let languages = ["python", "javascript", "java", "c++", "go", "ruby", "swift"]
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text("Interview Coder")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 8)
            
            // Instructions
            HStack(spacing: 16) {
                Text("Cmd+H: Screenshot")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("|")
                    .foregroundColor(.white.opacity(0.5))
                
                Text("Cmd+B: Toggle")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                    
                Text("|")
                    .foregroundColor(.white.opacity(0.5))
                    
                Text("Cmd+Return: Process")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.bottom, 4)
            
            // Screenshot queue
            if !screenshotManager.screenshots.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Screenshot Queue")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // Language selector
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
                        }
                        
                        Button(action: {
                            processScreenshots()
                        }) {
                            Text("Process")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.6))
                                .cornerRadius(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(screenshotManager.screenshots.indices, id: \.self) { index in
                                ScreenshotThumbnailView(
                                    thumbnail: screenshotManager.screenshots[index].thumbnail,
                                    onDelete: {
                                        screenshotManager.removeScreenshot(at: index)
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
            
            // Processing or result display
            if solutionState.isProcessing {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.0)
                            .padding(8) // Add some padding to prevent constraint errors
                        
                        Text("Analyzing screenshot and generating solution...")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
                    
                    Spacer()
                }
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
                        .padding(.horizontal, 12)
                }
            } else if let solution = solutionState.solution {
                ScrollView {
                    SolutionView(solution: solution)
                        .padding(.horizontal, 12)
                }
            } else {
                // Empty state - show a hint
                VStack {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("Take a screenshot of a coding problem to get started")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    Spacer()
                }
            }
            
            Spacer(minLength: 0)
            
            // Status bar
            HStack {
                if screenshotManager.isCapturing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16) // Fixed size to prevent constraint issues
                    
                    Text("Capturing...")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    Image(systemName: "keyboard")
                        .foregroundColor(.white.opacity(0.6))
                    Text("Cmd+Arrow: Move Window")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.bottom, 8)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.6))
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
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text(problemStatement)
                        .font(.system(size: 14))
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
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    ForEach(thoughts, id: \.self) { thought in
                        HStack(alignment: .top) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundColor(.blue)
                                .padding(.top, 6)
                            Text(thought)
                                .font(.system(size: 14))
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
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    ScrollView([.horizontal, .vertical]) {
                        Text(code)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.green.opacity(0.9))
                            .padding(8)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(4)
                    .frame(height: min(CGFloat(code.components(separatedBy: "\n").count) * 20 + 16, 300))
                }
                .padding(12)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
            
            if let timeComplexity = solution.time_complexity, let spaceComplexity = solution.space_complexity {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Complexity Analysis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    HStack {
                        Text("Time: ")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        Text(timeComplexity)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    HStack {
                        Text("Space: ")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        Text(spaceComplexity)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
        }
        .padding(.vertical, 12)
    }
}

struct SolutionDebugView: View {
    let solution: SolutionResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let thoughts = solution.thoughts, !thoughts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What I Changed")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    ForEach(thoughts, id: \.self) { thought in
                        HStack(alignment: .top) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundColor(.blue)
                                .padding(.top, 6)
                            Text(thought)
                                .font(.system(size: 14))
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
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    ScrollView([.horizontal, .vertical]) {
                        Text(code)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.green.opacity(0.9))
                            .padding(8)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(4)
                    .frame(height: min(CGFloat(code.components(separatedBy: "\n").count) * 20 + 16, 300))
                }
                .padding(12)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
            
            if let timeComplexity = solution.time_complexity, let spaceComplexity = solution.space_complexity {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Complexity Analysis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    HStack {
                        Text("Time: ")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        Text(timeComplexity)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    HStack {
                        Text("Space: ")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        Text(spaceComplexity)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
        }
        .padding(.vertical, 12)
    }
}

struct ScreenshotThumbnailView: View {
    let thumbnail: NSImage
    let onDelete: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 128, height: 72)
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
        .frame(width: 128, height: 72)
    }
}
