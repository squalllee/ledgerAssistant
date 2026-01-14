import Foundation
import UIKit

class AIService {
    static let shared = AIService()
    
    // Replace with your actual AI endpoint
    private let apiUrl = "https://ollama.com/api/chat"
    
    private var apiKey: String {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let key = dict["AI_API_KEY"] as? String else {
            return ""
        }
        return key
    }
    
    private let systemInstruction = """
    You are a professional receipt analysis expert. 
    Your task is to extract items and their total amounts from receipt images or text. 
    
    Categorization Rules (Output exactly one of these categories):
    - 食: Groceries, meals, drinks, snacks.
    - 衣: Clothes, shoes, accessories.
    - 住: Rent, utilities, home maintenance.
    - 行: Fuel, tolls, public transport, parking.
    - 娛: Movies, games, traveling, social activities, hobbies.
    - 樂: Music, streaming, digital subscriptions, app store.
    - 其它: Anything else.
    
    Return only a JSON object containing an array of items with 'name', 'amount', and 'category' fields. 
    Example: {"items": [{"name": "YouTube Premium", "amount": 199, "category": "樂"}]}
    """
    
    func analyzeReceipt(image: UIImage) async throws -> [ExtractedItem] {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to process image data"])
        }
        
        let base64Image = imageData.base64EncodedString()
        
        let payload: [String: Any] = [
            "model": "gemini-3-flash-preview:latest",
            "messages": [
                [
                    "role": "user",
                    "content": systemInstruction + "\n\nPlease analyze this receipt.",
                    "images": [base64Image]
                ]
            ],
            "stream": false,
            "format": "json"
        ]
        
        var request = URLRequest(url: URL(string: apiUrl)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "AIService", code: -2, userInfo: [NSLocalizedDescriptionKey: "API Request failed"])
        }
        
        let json = try JSONDecoder().decode(AIResponse.self, from: data)
        let content = (json.message.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle potential markdown backticks
        let cleanedContent = content.replacingOccurrences(of: "```json", with: "")
                                    .replacingOccurrences(of: "```", with: "")
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let result = try JSONDecoder().decode(ExtractionResult.self, from: Data(cleanedContent.utf8))
        return result.items
    }
    
    func analyzeVoiceText(text: String) async throws -> [ExtractedItem] {
        let payload: [String: Any] = [
            "model": "gemini-3-flash-preview:latest",
            "messages": [
                [
                    "role": "user",
                    "content": systemInstruction + "\n\nPlease parse the following voice description of an expense:\n\"" + text + "\""
                ]
            ],
            "stream": false,
            "format": "json"
        ]
        
        var request = URLRequest(url: URL(string: apiUrl)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONDecoder().decode(AIResponse.self, from: data)
        let content = (json.message.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        let cleanedContent = content.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let result = try JSONDecoder().decode(ExtractionResult.self, from: Data(cleanedContent.utf8))
        return result.items
    }
}

// Updated models for tool calling
struct AIResponse: Codable {
    let message: AIMessage
}

struct AIMessage: Codable {
    let content: String?
    let tool_calls: [ToolCall]?
}

struct ToolCall: Codable {
    let id: String
    let type: String
    let function: ToolFunction
}

struct ToolFunction: Codable {
    let name: String
    let arguments: String
}

struct ExtractionResult: Codable {
    let items: [ExtractedItem]
}

struct ExtractedItem: Codable {
    let name: String
    let amount: Double
    let category: String?
}
