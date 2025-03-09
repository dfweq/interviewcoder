import SwiftUI

struct APIKeyPromptView: View {
    @State private var apiKey: String = ""
    @State private var showInvalidKeyAlert = false
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("OpenAI API Key Required")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Please enter your OpenAI API key to continue.")
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
            
            SecureField("API Key", text: $apiKey)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            Button("Submit") {
                if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    APIKeyManager.saveAPIKey(apiKey)
                    isPresented = false
                } else {
                    showInvalidKeyAlert = true
                }
            }
            .buttonStyle(.borderedProminent)
            .padding()
            .alert("Invalid API Key", isPresented: $showInvalidKeyAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please enter a valid API key.")
            }
        }
        .padding()
        .frame(width: 400)
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
        .fixedSize(horizontal: true, vertical: true)
    }
}
