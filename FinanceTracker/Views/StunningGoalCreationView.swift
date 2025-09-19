import SwiftUI
import Appwrite

struct StunningGoalCreationView: View {
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
        VStack {
            // Back button and header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
                
                Spacer()
                
                Text("Create Goal")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Invisible spacer for balance
                Circle()
                    .frame(width: 34, height: 34)
                    .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            // Main content without scroll
            VStack(spacing: 20) {
                // Simplified hero section
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.blue.opacity(0.6), .purple.opacity(0.3), .clear],
                                    center: .center,
                                    startRadius: 15,
                                    endRadius: 40
                                )
                            )
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "target")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 4) {
                        Text("Create Your Goal")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Set your financial target")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.top, 10)
                
                // Compact form card
                VStack(spacing: 20) {
                    // Goal Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Goal Name")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                        
                        TextField("Enter your goal...", text: $goalName)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(
                                                goalName.isEmpty ? .white.opacity(0.3) : .blue.opacity(0.6),
                                                lineWidth: 1
                                            )
                                    )
                            )
                            .foregroundColor(.white)
                    }
                    
                    // Target Amount
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Target Amount")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                        
                        HStack(spacing: 12) {
                            Text("R")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                                .frame(width: 30)
                            
                            TextField("0.00", value: $targetAmount, format: .number)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .keyboardType(.decimalPad)
                                .foregroundColor(.white)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(
                                            targetAmount <= 0 ? .white.opacity(0.3) : .orange.opacity(0.6),
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                    
                    // Account Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Link to Account")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                        
                        if accounts.isEmpty {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .tint(.cyan)
                                    .scaleEffect(0.9)
                                
                                Text("Loading accounts...")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        } else {
                            Menu {
                                ForEach(accounts, id: \.accountId) { account in
                                    Button(action: {
                                        selectedAccountId = account.accountId
                                    }) {
                                        HStack {
                                            Image(systemName: "creditcard.fill")
                                            Text(account.displayName)
                                                .font(.system(size: 15, weight: .medium))
                                            if selectedAccountId == account.accountId {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green)
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "creditcard.fill")
                                        .foregroundColor(.cyan)
                                        .font(.system(size: 16))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(selectedAccountId != nil ? 
                                             accounts.first(where: { $0.accountId == selectedAccountId })?.displayName ?? "Select account" : 
                                             "Select account")
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(.white)
                                        
                                        if selectedAccountId != nil {
                                            Text("Account linked ✓")
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                                .foregroundColor(.green.opacity(0.8))
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.cyan)
                                        .font(.system(size: 14))
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(
                                                    selectedAccountId == nil ? .white.opacity(0.3) : .cyan.opacity(0.6),
                                                    lineWidth: 1
                                                )
                                        )
                                )
                            }
                        }
                    }
                    
                    // Create Goal Button
                    Button(action: createGoal) {
                        HStack(spacing: 10) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.9)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            
                            Text(isLoading ? "Creating..." : "Create Goal")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(18)
                        .background(
                            LinearGradient(
                                colors: isFormValid && !isLoading ? 
                                    [.blue, .purple] : 
                                    [.gray.opacity(0.6), .gray.opacity(0.4)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(
                            color: isFormValid && !isLoading ? .blue.opacity(0.3) : .clear,
                            radius: 8,
                            y: 4
                        )
                    }
                    .disabled(!isFormValid || isLoading)
                    .scaleEffect(isFormValid && !isLoading ? 1.0 : 0.98)
                    .animation(.easeInOut(duration: 0.2), value: isFormValid)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Simple confetti
            if showConfetti {
                ConfettiView()
                    .transition(.opacity)
                    .zIndex(1000)
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.3),
                    Color(red: 0.2, green: 0.1, blue: 0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .navigationBarHidden(true)
        .onAppear {
            Task { await loadAccounts() }
        }
        .alert("Goal Created! 🎉", isPresented: $showSuccess) {
            Button("Great!") { }
        } message: {
            Text("Your goal has been created successfully!")
        }
    }
    
    private var isFormValid: Bool {
        !goalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
        targetAmount > 0 && 
        selectedAccountId != nil && 
        !isLoading
    }
    
    private func loadAccounts() async {
        do {
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
            
            do {
                _ = try await appwriteService.createGoal(
                    name: goalName,
                    targetAmount: targetAmount,
                    isTracked: true,
                    linkedAccountId: accountId
                )
                
                await MainActor.run {
                    showConfetti = true
                    showSuccess = true
                    goalName = ""
                    targetAmount = 0.0
                    selectedAccountId = nil
                    isLoading = false
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
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
        StunningGoalCreationView()
            .environmentObject(AppwriteService.shared)
    }
}
