import SwiftUI

struct ContentView: View {
    @State private var auth = AuthManager()
    
    var body: some View {
        if auth.isAuthenticated {
            DashboardView(auth: auth)
        } else {
            // Pass the shared instance down to the login screen!
            LoginView(auth: auth)
        }
    }
}

#Preview {
    ContentView()
}
