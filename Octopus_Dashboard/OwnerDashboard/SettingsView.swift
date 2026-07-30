import SwiftUI

struct SettingsView: View {
    @Bindable var auth: AuthManager
    
    // Auto-saving preferences using AppStorage
    @AppStorage("useLiquidGlass") private var useLiquidGlass = true
    @AppStorage("glassTransparency") private var glassTransparency = 0.2
    @AppStorage("isDarkMode") private var isDarkMode = true

    var body: some View {
        NavigationStack {
            ZStack {
                // Plain black or white background based on the mode preference
                (isDarkMode ? Color.black : Color.white)
                    .ignoresSafeArea()

                List {
                    Section(header: Text("Account")) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(isDarkMode ? .white : .black)
                                .font(.title2)
                            Text(auth.email)
                                .foregroundColor(isDarkMode ? .white : .black)
                        }
                        
                        Button(role: .destructive, action: {
                            auth.isAuthenticated = false
                            auth.jwtToken = nil
                        }) {
                            Text("Sign Out")
                        }
                    }
                    .listRowBackground(rowBackground)
                    
                    Section(header: Text("Appearance & UI")) {
                        Toggle("Dark Mode", isOn: $isDarkMode)
                        
                        Toggle("Liquid Glass Effect", isOn: $useLiquidGlass)
                        
                        if useLiquidGlass {
                            VStack(alignment: .leading) {
                                Text("Glass Transparency: \(Int(glassTransparency * 100))%")
                                    .font(.caption)
                                Slider(value: $glassTransparency, in: 0.05...0.5, step: 0.05)
                                    .tint(isDarkMode ? .white : .black)
                            }
                        }
                    }
                    .listRowBackground(rowBackground)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            // Apply the dark/light mode preference strictly to this view hierarchy
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
    
    // Neutral row background: subtle grayscale contrast based on the mode
    private var rowBackground: some View {
        isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.04)
    }
}
