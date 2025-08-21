import SwiftUI

struct AuthView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLogin = true
    @State private var errorMessage: String?
    @State private var isLoading = false
    @EnvironmentObject var appwriteService: AppwriteService
    
    var body: some View {
        ZStack {
            // Beautiful gradient background
            LinearGradient(
                colors: [.blue.opacity(0.1), .purple.opacity(0.1)], 
                startPoint: .topLeading, 
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    Spacer(minLength: 60)
                    
                    // App icon and title
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 100, height: 100)
                                .shadow(color: .blue.opacity(0.3), radius: 20, x: 0, y: 10)
                            
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                        }
                        
                        VStack(spacing: 8) {
                            Text("Finance Tracker")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("Track your savings goals with ease")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Auth form card
                    VStack(spacing: 24) {
                        // Toggle between login/signup
                        HStack(spacing: 0) {
                            Button(action: { isLogin = true }) {
                                Text("Login")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(isLogin ? .white : .blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        isLogin ? .blue : .clear,
                                        in: RoundedRectangle(cornerRadius: 12)
                                    )
                            }
                            
                            Button(action: { isLogin = false }) {
                                Text("Sign Up")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(!isLogin ? .white : .blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        !isLogin ? .blue : .clear,
                                        in: RoundedRectangle(cornerRadius: 12)
                                    )
                            }
                        }
                        .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                        
                        // Form fields
                        VStack(spacing: 16) {
                            // Email field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Email")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                TextField("Enter your email", text: $email)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .padding(16)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(.blue.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            
                            // Password field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Password")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                SecureField("Enter your password", text: $password)
                                    .padding(16)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(.blue.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                        
                        // Error message
                        if let errorMessage = errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(errorMessage)
                                    .font(.system(size: 14))
                                    .foregroundColor(.red)
                                Spacer()
                            }
                            .padding(12)
                            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        }
                        
                        // Submit button
                        Button(action: handleAuth) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                } else {
                                    Image(systemName: isLogin ? "person.fill" : "person.badge.plus.fill")
                                    Text(isLogin ? "Login" : "Create Account")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(email.isEmpty || password.isEmpty || isLoading)
                        .opacity((email.isEmpty || password.isEmpty || isLoading) ? 0.6 : 1.0)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                }
            }
        }
    }
    
    private func handleAuth() {
        Task {
            errorMessage = nil
            isLoading = true
            
            do {
                if isLogin {
                    try await appwriteService.signIn(email: email, password: password)
                } else {
                    try await appwriteService.signUp(email: email, password: password)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AppwriteService.shared)
}
