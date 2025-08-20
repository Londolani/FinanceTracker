import SwiftUI

struct AuthView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLogin = true
    @State private var errorMessage: String?
    @EnvironmentObject var appwriteService: AppwriteService
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                
                Text("Finance Tracker")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                VStack(spacing: 20) {
                    Text(isLogin ? "Welcome Back!" : "Create an Account")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    VStack(spacing: 15) {
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                    
                    Button(isLogin ? "Login" : "Sign Up") {
                        Task {
                            errorMessage = nil
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
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    
                    Button(isLogin ? "Don't have an account? Sign Up" : "Already have an account? Login") {
                        isLogin.toggle()
                        errorMessage = nil
                    }
                    .foregroundColor(.white)
                    .font(.caption)
                }
                .padding(.horizontal, 30)
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AppwriteService.shared)
}