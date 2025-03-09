import Foundation
import SwiftUI

class OpenAIService {
    // Use stored API key from UserDefaults
    private var apiKey: String {
        return APIKeyManager.getAPIKey() ?? ""
    }
    private let apiUrl = "https://api.openai.com/v1/chat/completions"
    
    static let shared = OpenAIService()
    
    private init() {}
    
    func analyzeScreenshot(image: NSImage, language: String = "python", completion: @escaping (Result<SolutionResult, Error>) -> Void) {
        guard !apiKey.isEmpty else {
            completion(.failure(OpenAIError.invalidAPIKey))
            return
        }
        
        guard let base64Image = convertImageToBase64(image) else {
            completion(.failure(OpenAIError.imageConversionFailed))
            return
        }
        
        // Create request
        guard let url = URL(string: apiUrl) else {
            completion(.failure(OpenAIError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": """
                        You are an expert coding interview assistant. Analyze this coding problem screenshot and provide:
                        1. Problem Statement: Extract and summarize the problem.
                        2. Solution: Provide an optimal solution in \(language).
                        3. Explanation: Explain your approach and the reasoning behind it.
                        4. Time & Space Complexity: Analyze the complexity.
                        
                        Format your response as JSON with these keys: problem_statement, code, thoughts (array), time_complexity, space_complexity.
                        """],
                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]]
                    ]
                ]
            ],
            "max_tokens": 4000,
            "response_format": ["type": "json_object"]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        // Send request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(OpenAIError.noData))
                return
            }
            
            // Parse response
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                if let responseJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = responseJson["error"] as? [String: Any],
                   let message = errorMessage["message"] as? String {
                    completion(.failure(OpenAIError.apiError(message)))
                } else {
                    completion(.failure(OpenAIError.httpError(httpResponse.statusCode)))
                }
                return
            }
            
            // First try to parse as JSON directly
            let jsonDecoder = JSONDecoder()
            // First try to parse as OpenAI response
            if let apiResponse = try? jsonDecoder.decode(OpenAIResponse.self, from: data),
               let choices = apiResponse.choices.first,
               let content = choices.message.content {
                
                // Parse the content which should be a JSON string
                if let contentData = content.data(using: .utf8) {
                    do {
                        let solution = try jsonDecoder.decode(SolutionResult.self, from: contentData)
                        completion(.success(solution))
                    } catch {
                        print("JSON parsing error from content: \(error)")
                        completion(.failure(OpenAIError.parsingFailed))
                    }
                } else {
                    completion(.failure(OpenAIError.parsingFailed))
                }
            } else {
                // Try to parse as raw JSON directly in case API didn't wrap properly
                do {
                    let solution = try jsonDecoder.decode(SolutionResult.self, from: data)
                    completion(.success(solution))
                } catch {
                    print("JSON parsing error from raw data: \(error)")
                    completion(.failure(OpenAIError.parsingFailed))
                }
            }
        }
        
        task.resume()
    }
    
    // Add a debug method for processing an extra screenshot
    func debugWithExtraScreenshot(originalScreenshots: [NSImage], newScreenshot: NSImage, language: String = "python", completion: @escaping (Result<SolutionResult, Error>) -> Void) {
        guard !apiKey.isEmpty else {
            completion(.failure(OpenAIError.invalidAPIKey))
            return
        }
        
        // Combine all images as base64
        var base64Images = [String]()
        
        // Convert all images to base64
        for image in originalScreenshots + [newScreenshot] {
            guard let base64Image = convertImageToBase64(image) else {
                continue
            }
            base64Images.append(base64Image)
        }
        
        if base64Images.isEmpty {
            completion(.failure(OpenAIError.imageConversionFailed))
            return
        }
        
        // Create a more complex prompt
        guard let url = URL(string: apiUrl) else {
            completion(.failure(OpenAIError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Build a message array with all images
        var messages: [[String: Any]] = [
            [
                "role": "system",
                "content": """
                You are a coding interview assistant helping debug code. Review both the problem and the user's solution, identify issues, and provide an improved solution.
                """
            ]
        ]
        
        // Add the problem statement from the first image
        var content: [[String: Any]] = [
            ["type": "text", "text": "Here is the original problem:"]
        ]
        
        // Add the first image
        if let firstImage = base64Images.first {
            content.append(["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(firstImage)"]])
        }
        
        // Add explanation for additional images
        content.append(["type": "text", "text": "Here is my attempted solution/code:"])
        
        // Add the rest of the images
        for base64Image in base64Images.dropFirst() {
            content.append(["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]])
        }
        
        content.append(["type": "text", "text": """
        Analyze my solution, find any bugs or issues, and provide an improved solution. Format your response as JSON with these keys:
        - new_code: The improved solution code
        - thoughts: An array of string comments about what was wrong and how it was fixed
        - time_complexity: The time complexity analysis
        - space_complexity: The space complexity analysis
        """])
        
        messages.append(["role": "user", "content": content])
        
        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages,
            "max_tokens": 4000,
            "response_format": ["type": "json_object"]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        // Send request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(OpenAIError.noData))
                return
            }
            
            // Parse response
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                if let responseJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = responseJson["error"] as? [String: Any],
                   let message = errorMessage["message"] as? String {
                    completion(.failure(OpenAIError.apiError(message)))
                } else {
                    completion(.failure(OpenAIError.httpError(httpResponse.statusCode)))
                }
                return
            }
            
            // Same parsing logic as the analyzeScreenshot method
            let jsonDecoder = JSONDecoder()
            
            // First try to parse as OpenAI response
            if let apiResponse = try? jsonDecoder.decode(OpenAIResponse.self, from: data),
               let choices = apiResponse.choices.first,
               let content = choices.message.content {
                
                if let contentData = content.data(using: .utf8) {
                    do {
                        let solution = try jsonDecoder.decode(SolutionResult.self, from: contentData)
                        completion(.success(solution))
                    } catch {
                        print("Debug JSON parsing error: \(error)")
                        completion(.failure(OpenAIError.parsingFailed))
                    }
                } else {
                    completion(.failure(OpenAIError.parsingFailed))
                }
            } else if let solution = try? jsonDecoder.decode(SolutionResult.self, from: data) {
                completion(.success(solution))
            } else {
                completion(.failure(OpenAIError.parsingFailed))
            }
        }
        
        task.resume()
    }
    
    private func convertImageToBase64(_ image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
            return nil
        }
        
        return jpegData.base64EncodedString()
    }
}

enum OpenAIError: Error, Equatable {
    case invalidURL
    case imageConversionFailed
    case noData
    case parsingFailed
    case apiError(String)
    case httpError(Int)
    case invalidAPIKey
    
    static func == (lhs: OpenAIError, rhs: OpenAIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.imageConversionFailed, .imageConversionFailed),
             (.noData, .noData),
             (.parsingFailed, .parsingFailed),
             (.invalidAPIKey, .invalidAPIKey):
            return true
        case let (.apiError(lhsMessage), .apiError(rhsMessage)):
            return lhsMessage == rhsMessage
        case let (.httpError(lhsCode), .httpError(rhsCode)):
            return lhsCode == rhsCode
        default:
            return false
        }
    }
}

// Models for OpenAI API responses
struct OpenAIResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    
    struct Choice: Codable {
        let index: Int
        let message: Message
        let finish_reason: String
    }
    
    struct Message: Codable {
        let role: String
        let content: String?
    }
}

// Model for the solution result
struct SolutionResult: Codable {
    var problem_statement: String?
    var code: String?
    var thoughts: [String]?
    var time_complexity: String?
    var space_complexity: String?
    
    // For debug/improved solution
    var new_code: String?
}
