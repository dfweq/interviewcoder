import SwiftUI

struct MainContentView: View {
    @ObservedObject private var screenshotManager = ScreenshotManager.shared
    
    var body: some View {
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
            
            // Show screenshot queue if there are any screenshots
            if !screenshotManager.screenshots.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Screenshot Queue")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
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
            
            Spacer()
            
            // Status and keyboard shortcuts
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
        .background(Color.black.opacity(0.6))
    }
}

// A view for displaying screenshot thumbnails with delete button
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
