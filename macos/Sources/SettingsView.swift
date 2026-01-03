import SwiftUI

struct SettingsView: View {
    @StateObject private var api = APIService.shared
    @StateObject private var syncManager = SyncManager.shared
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.headline)
            
            Divider()
            
            // CONFLICT RESOLUTION UI
            if !syncManager.conflictedPages.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("⚠️ Sync Conflicts Detected")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    ForEach(Array(syncManager.conflictedPages), id: \.self) { index in
                        HStack {
                            Text("Page \(index + 1)")
                            Spacer()
                            Button("Keep Local") {
                                syncManager.resolveConflict(index: index, keepLocal: true)
                            }
                            Button("Keep Server") {
                                syncManager.resolveConflict(index: index, keepLocal: false)
                            }
                        }
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
                Divider()
            }
            
            if api.isAuthenticated {
                // LOGGED IN STATE
                VStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 48, height: 48)
                        .foregroundColor(.green)
                    
                    Text("Logged in")
                        .foregroundColor(.green)
                    
                    Button("Sync Now") {
                        syncManager.triggerSync()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Logout") {
                        api.logout()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else {
                // AUTH FORM
                VStack(spacing: 12) {
                    Text(isSignUp ? "Create Account" : "Welcome Back")
                        .font(.title3)
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Button(action: handleAuth) {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text(isSignUp ? "Sign Up" : "Login")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(email.isEmpty || password.isEmpty || isLoading)
                    
                    Button(isSignUp ? "Already have an account? Login" : "New user? Sign Up") {
                        isSignUp.toggle()
                        errorMessage = ""
                    }
                    .buttonStyle(.link)
                }
                .padding()
                .frame(width: 300)
            }
        }
        .padding()
        .frame(width: 320)
    }
    
    private func handleAuth() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                if isSignUp {
                    _ = try await api.signup(email: email, password: password)
                } else {
                    _ = try await api.login(email: email, password: password)
                }
                if api.isAuthenticated {
                    SyncManager.shared.triggerSync()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
