import Foundation
import SwiftUI

// This matches the exact response shape from your C# backend[cite: 14]
struct LoginResponse: Codable {
    let success: Bool?
    let token: String?
    let message: String?
}

// Quick-switch presets for the login screen's environment picker. The API
// Base URL field stays freely editable for anything outside these two.
enum ApiEnvironment: String, CaseIterable, Identifiable {
    case dev = "Dev"
    case test = "Test"

    var id: String { rawValue }

    var baseUrl: String {
        switch self {
        // Local dev backend over Tailscale.
        case .dev: return "http://100.114.12.38:5002/api"
        // OVH-hosted test backend (see HANDOFF.md) — real HTTPS via sslip.io.
        case .test: return "https://51-91-6-6.sslip.io/api"
        }
    }
}

@Observable
class AuthManager {
    var email = "ilyasschah18@gmail.com"
    var password = "Admin@123"
    var apiBaseUrl = "https://51-91-6-6.sslip.io/api"
    
    var isLoading = false
    var errorMessage: String? = nil
    var isAuthenticated = false
    var jwtToken: String? = nil
    
    func login() async {
        isLoading = true
        errorMessage = nil
        
        // 1. Setup the URL
        guard let url = URL(string: "\(apiBaseUrl)/Auth/Login") else {
            errorMessage = "Invalid API URL"
            isLoading = false
            return
        }
        
        // 2. Prepare the payload (Sending DeviceId as null to try and avoid burning a seat)[cite: 14]
        let payload: [String: Any?] = [
            "Email": email,
            "Password": password,
            "DeviceId": nil
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            // 3. Make the network call
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Invalid server response"
                isLoading = false
                return
            }
            
            // 4. Parse the JSON
            let decoder = JSONDecoder()
            // Your backend might send PascalCase or camelCase, this handles both
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            if httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let token = json["Token"] as? String ?? json["token"] as? String {
                    
                    self.jwtToken = token
                    self.isAuthenticated = true
                    print("SUCCESS! Token acquired: \(token.prefix(15))...")
                    
                } else {
                    errorMessage = "Login failed: Could not read token from response."
                }
            } else {
                errorMessage = "Unauthorized (Error \(httpResponse.statusCode))"
            }
            
        } catch {
            errorMessage = "Network error: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}//
//  AuthManager.swift
//  OwnerDashboard
//
//  Created by ILYASS on 25/7/2026.
//

