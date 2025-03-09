import Foundation

class APIKeyManager {
    private static let keyStorageKey = "openai_api_key"
    
    static func saveAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: keyStorageKey)
    }
    
    static func getAPIKey() -> String? {
        return UserDefaults.standard.string(forKey: keyStorageKey)
    }
    
    static func hasAPIKey() -> Bool {
        if let key = getAPIKey() {
            return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return false
    }
}
