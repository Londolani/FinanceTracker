import SwiftUI
import Appwrite

struct CredentialsView: View {
    @State private var apiKey = ""
    @State private var clientId = ""
    @State private var clientSecret = ""
    @State private var showSuccess = false
    @State private var isLoading = false
    @EnvironmentObject var appwriteService: AppwriteService
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [.green.opacity(0.1), .mint.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "building.2.fill")
                                .foregroundColor(.green)
                            Text("Investec API Integration")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        Text("Connect your Investec account to automatically track transactions and update your savings goals.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("API Credentials")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter your API key", text: $apiKey)
                            .autocapitalization(.none)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Client ID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter your client ID", text: $clientId)
                            .autocapitalization(.none)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Client Secret")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        SecureField("Enter your client secret", text: $clientSecret)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                Section {
                    Button("Save Credentials") {
                        saveCredentials()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(apiKey.isEmpty || clientId.isEmpty || clientSecret.isEmpty || isLoading)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "shield.fill")
                                .foregroundColor(.blue)
                            Text("Security Note")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        Text("Your credentials are securely encrypted and stored. They are only used to connect to your Investec account and retrieve transaction data.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Connect Investec")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Credentials Saved!", isPresented: $showSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your Investec credentials have been securely saved.")
        }
        .overlay {
            if isLoading {
                ProgressView("Saving...")
                    .scaleEffect(1.5)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
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
