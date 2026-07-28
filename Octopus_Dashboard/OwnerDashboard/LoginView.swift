//
//  LoginView.swift
//  OwnerDashboard
//
//  Created by ILYASS on 25/7/2026.
//

import SwiftUI

struct LoginView: View {
    @Bindable var auth: AuthManager // Add this line instead
    @State private var showPassword = false
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    var body: some View {
        ZStack {
            // 1. Plain black or white background based on the mode preference
            (isDarkMode ? Color.black : Color.white).ignoresSafeArea()

            // 2. The Glassmorphism Card
            VStack(spacing: 24) {
                Text("Octopus Owner")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Business Dashboard")
                    .font(.subheadline)
                    .foregroundColor(.primary.opacity(0.7))
                    .padding(.bottom, 10)
                
                // API URL Field[cite: 14]
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Base URL")
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.8))
                    TextField("http://...", text: $auth.apiBaseUrl)
                        .padding()
                        .background(Color.primary.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.primary)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                // Email Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.8))
                    TextField("Email", text: $auth.email)
                        .padding()
                        .background(Color.primary.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.primary)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                // Password Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.8))
                    
                    HStack {
                        if showPassword {
                            TextField("Password", text: $auth.password)
                                .foregroundColor(.primary)
                        } else {
                            SecureField("Password", text: $auth.password)
                                .foregroundColor(.primary)
                        }
                        
                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.primary.opacity(0.6))
                        }
                    }
                    .padding()
                    .background(Color.primary.opacity(0.1))
                    .cornerRadius(12)
                }
                
                if let error = auth.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }
                
                // Login Button
                Button(action: {
                    Task {
                        await auth.login()
                    }
                }) {
                    ZStack {
                        if auth.isLoading {
                            ProgressView()
                                .tint(.primary)
                        } else {
                            Text("Sign In")
                                .fontWeight(.bold)
                        }
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.teal)
                    .cornerRadius(12)
                }
                .disabled(auth.isLoading)
                .padding(.top, 10)
            }
            .padding(30)
            // THE LIQUID GLASS EFFECT
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

#Preview {
    LoginView(auth: AuthManager())
}
