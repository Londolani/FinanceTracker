import SwiftUI
import Appwrite

struct GoalCreationView: View {
    @State private var goalName = ""
    @State private var targetAmount = 0.0
    @State private var showSuccess = false
    @State private var showConfetti = false
    @State private var isLoading = false
    @State private var selectedAccountId: String?
    @State private var accounts: [InvestecService.AccountResponse.Account] = []
    @EnvironmentObject var appwriteService: AppwriteService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [.blue.opacity(0.1), .cyan.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            Form {
                Section(header: Text("New Savings Goal").font(.headline)) {
                    TextField("Goal Name (e.g., 'Car Loan')", text: $goalName)
                    
                    HStack {
                        Text("R")
                        TextField("Target Amount", value: $targetAmount, format: .number)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section(header: Text("Link to Account")) {
                    if accounts.isEmpty {
                        Text("Loading accounts...")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Select Account", selection: $selectedAccountId) {
                            Text("Select account").tag(nil as String?)
                            ForEach(accounts, id: \.accountId) { account in
                                Text(account.displayName)
                                    .tag(account.accountId as String?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    Text("This goal will track transfers from/to the selected account")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Button("Create Goal") {
                        createGoal()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(goalName.isEmpty || targetAmount <= 0 || selectedAccountId == nil || isLoading)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Create Goal")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await loadAccounts()
            }
        }
        .alert("Goal Created!", isPresented: $showSuccess) {
            Button("OK", role: .cancel) { }
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
            if showConfetti {
                ConfettiView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
    }
    
    private func loadAccounts() async {
        do {
            // Get credentials
            let credentialsList = try await appwriteService.databases.listDocuments(
                databaseId: appwriteService.databaseId,
                collectionId: appwriteService.credentialsCollectionId
            )
            
            guard let doc = credentialsList.documents.first,
                  let apiKey = doc.data["investec_api_key"]?.value as? String,
                  let clientId = doc.data["client_id"]?.value as? String,
                  let clientSecret = doc.data["client_secret"]?.value as? String else {
                return
            }
            
            // Get accounts from Investec API
            let fetchedAccounts = try await InvestecService.shared.getAccounts(
                apiKey: apiKey,
                clientId: clientId,
                clientSecret: clientSecret
            )
            
            await MainActor.run {
                self.accounts = fetchedAccounts
            }
        } catch {
            print("Error loading accounts: \(error.localizedDescription)")
        }
    }
    
    private func createGoal() {
        Task {
            guard let userId = appwriteService.currentUser?.id,
                  let accountId = selectedAccountId else { return }
            
            await MainActor.run { isLoading = true }
            
            let newGoal = [
                "user_id": userId,
                "name": goalName,
                "target_amount": targetAmount,
                "saved_amount": 0.0,
                "is_tracked": true,
                "linkedAccountId": accountId // <-- changed to camelCase
            ] as [String : Any]
            
            let permissions = [
                Permission.read(Role.user(userId)),
                Permission.write(Role.user(userId))
            ]
            
            do {
                _ = try await appwriteService.databases.createDocument(
                    databaseId: appwriteService.databaseId,
                    collectionId: appwriteService.goalsCollectionId,
                    documentId: "unique()",
                    data: newGoal,
                    permissions: permissions
                )
                await MainActor.run {
                    showConfetti = true
                    showSuccess = true
                    goalName = ""
                    targetAmount = 0.0
                    selectedAccountId = nil
                    isLoading = false
                }
                
                // Navigate back to home screen after confetti animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    dismiss()
                }
            } catch {
                print("Error creating goal: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}

#Preview {
    NavigationView {
        GoalCreationView()
            .environmentObject(AppwriteService.shared)
    }
}
