import SwiftUI

struct MainContentView: View {
    @ObservedObject private var screenshotManager = ScreenshotManager.shared
    @ObservedObject private var solutionState = SolutionState.shared
    @State private var selectedLanguage = "python"
    @State private var showLanguageSelector = false
    
    let languages = ["python", "javascript", "java", "c++", "go", "ruby", "swift"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Interview Coder")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                // Instructions
                Text("Press Cmd+H to take a screenshot")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Press Cmd+B to toggle visibility")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                
                // Screenshot queue
                if !screenshotManager.screenshots.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Screenshot Queue")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button(action: {
                                showLanguageSelector.toggle()
                            }) {
                                HStack {
                                    Text(selectedLanguage)
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.8))
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(4)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if showLanguageSelector {
                                Menu("") {
                                    ForEach(languages, id: \.self) { language in
                                        Button(language) {
                                            selectedLanguage = language
                                            showLanguageSelector = false
                                        }
                                    }
                                }
                                .menuIndicator(.hidden)
                                .menuStyle(.borderlessButton)
                            }
                            
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
                    .padding(10)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                }
                
                // Processing or result display
                if solutionState.isProcessing {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.0)
                        Text("Analyzing screenshot and generating solution...")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                } else if let errorMessage = solutionState.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                } else if solutionState.isDebugMode, let debugSolution = solutionState.debugSolution {
                    SolutionDebugView(solution: debugSolution)
                } else if let solution = solutionState.solution {
                    SolutionView(solution: solution)
                }
                
                Spacer()
                
                // Status bar
                HStack {
                    if screenshotManager.isCapturing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.7)
                        Text("Capturing...")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    } else {
                        Image(systemName: "keyboard")
                            .foregroundColor(.white.opacity(0.6))
                        Text("Cmd+H: Screenshot | Cmd+B: Toggle | Cmd+Arrow: Move")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.bottom, 10)
            }
            .padding(20)
        }
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

// SolutionView and other subviews remain unchanged
struct SolutionView: View {
    let solution: SolutionResult
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
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
                    .padding(10)
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
                    .padding(10)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                }
                if let code = solution.code {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Solution")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(code)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.green.opacity(0.9))
                                .padding(8)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(4)
                    }
                    .padding(10)
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
                    .padding(10)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                }
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SolutionDebugView: View {
    let solution: SolutionResult
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
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
                    .padding(10)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                }
                if let code = solution.new_code {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Improved Solution")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(code)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.green.opacity(0.9))
                                .padding(8)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(4)
                    }
                    .padding(10)
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
                    .padding(10)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                }
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
