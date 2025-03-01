//
//  LLMService.swift
//  AppWarmr
//
//  Created by Michelle Rueda on 2/28/25.
//

import Foundation

struct LLMService {
  
  static func sendToGroq(businessInfo: String, idealCustomerInfo: String) async throws -> String {
      // Create the request URL
      guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
          throw NSError(domain: "LLMService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
      }
      
      // Create the request
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue("Bearer \(ServiceKeys.groq_key)", forHTTPHeaderField: "Authorization")
      
      // Construct the message
      let prompt = "My business is \(businessInfo). I think my ideal customer is \(idealCustomerInfo). Can you provide a generalized description of the type of vibe for content you think this customer would like on social media? Please do not make it too specific, more a general feel. Please do not include any intro text or lists, just a description of the content."
      
      // Create the request body
      let payload: [String: Any] = [
          "model": "llama-3.3-70b-versatile",
          "messages": [
              [
                  "role": "user",
                  "content": prompt
              ]
          ],
          "temperature": 1,
          "max_tokens": 1024,
          "top_p": 1,
          "stream": false
      ]
      
      // Convert payload to JSON data
      do {
          request.httpBody = try JSONSerialization.data(withJSONObject: payload)
      } catch {
          throw error
      }
      
      // Use async/await instead of completion handler
      let (data, _) = try await URLSession.shared.data(for: request)
      
      // Parse the response
      if let responseJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
         let choices = responseJson["choices"] as? [[String: Any]],
         let firstChoice = choices.first,
         let message = firstChoice["message"] as? [String: Any],
         let content = message["content"] as? String {
          return content
      } else if let responseString = String(data: data, encoding: .utf8) {
          return "Received unexpected response: \(responseString)"
      } else {
          throw NSError(domain: "LLMService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])
      }
  }
}
