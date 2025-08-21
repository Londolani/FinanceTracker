import SwiftUI
import Appwrite

struct CredentialsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    @State private var clientId = ""
    @State private var clientSecret = ""
    @State private var showSuccess = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @EnvironmentObject var appwriteService: AppwriteService
    
    var body: some View {
        VStack(spacing: 0) {
            // Header section
            headerSection
            
            // Main content
            ScrollView {
                VStack(spacing: 24) {
                    // Info card
                    infoCard
                    
                    // Credentials form
                    credentialsForm
                    
                    // Save button
                    saveButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(
                LinearGradient(
                    colors: [.blue.opacity(0.05), .purple.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
        }
        .navigationBarHidden(true)
        .alert("Success!", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your Investec credentials have been saved successfully!")
        }
        .task {
            await loadExistingCredentials()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Navigation header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
                
                Spacer()
                
                Text("Bank Connection")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                
                Spacer()
                
                Circle()
                    .frame(width: 34, height: 34)
                    .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
    }
    
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.green.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.green)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Investec API Integration")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Secure banking connection")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Text("Connect your Investec account to automatically track transactions and update your savings goals. Your credentials are stored securely and encrypted.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private var credentialsForm: some View {
        VStack(spacing: 20) {
            // Form header
            HStack {
                Text("API Credentials")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // API Key field
            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField("Enter your Investec API key", text: $apiKey)
                    .autocapitalization(.none)
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.green.opacity(0.3), lineWidth: 1)
                    )
            }
            
            // Client ID field
            VStack(alignment: .leading, spacing: 8) {
                Text("Client ID")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField("Enter your client ID", text: $clientId)
                    .autocapitalization(.none)
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.green.opacity(0.3), lineWidth: 1)
                    )
            }
            
            // Client Secret field
            VStack(alignment: .leading, spacing: 8) {
                Text("Client Secret")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                SecureField("Enter your client secret", text: $clientSecret)
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.green.opacity(0.3), lineWidth: 1)
                    )
            }
            
            // Error message
            if let errorMessage = errorMessage {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                    
                    Spacer()
                }
                .padding(12)
                .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.red.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private var saveButton: some View {
        Button(action: saveCredentials) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                    
                    Text("Save Credentials")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [.green, .green.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(apiKey.isEmpty || clientId.isEmpty || clientSecret.isEmpty || isLoading)
        .opacity((apiKey.isEmpty || clientId.isEmpty || clientSecret.isEmpty || isLoading) ? 0.6 : 1.0)
    }
    
    private func loadExistingCredentials() async {
        // Implementation for loading existing credentials
    }
    
    private func saveCredentials() {
        Task {
            guard let userId = appwriteService.currentUser?.id else { return }
            
            await MainActor.run { isLoading = true }
            
            let credentials = [
                "user_id": userId,
                "investec_api_key": apiKey,
                "client_id": clientId,
                "client_secret": clientSecret
            ] as [String : Any]
            
            let permissions = [
                Permission.read(Role.user(userId)),
                Permission.write(Role.user(userId))
            ]
            
            print("Saving credentials with structure: \(credentials)")
            
            do {
                _ = try await appwriteService.databases.createDocument(
                    databaseId: appwriteService.databaseId,
                    collectionId: appwriteService.credentialsCollectionId,
                    documentId: "unique()",
                    data: credentials,
                    permissions: permissions
                )
                await MainActor.run {
                    showSuccess = true
                    apiKey = ""
                    clientId = ""
                    clientSecret = ""
                    isLoading = false
                }
            } catch {
                print("Error saving credentials: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}

#Preview {
    NavigationView {
        CredentialsView()
            .environmentObject(AppwriteService.shared)
    }
}
