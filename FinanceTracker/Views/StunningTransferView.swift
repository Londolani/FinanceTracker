import SwiftUI
import Appwrite

struct StunningTransferView: View {
    @EnvironmentObject var appwriteService: AppwriteService
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showSuccessOverlay = false
    @State private var transferAmount: String = ""
    @State private var isOutgoingTransfer: Bool = false
    
    // Investec account data
    @State private var accounts: [InvestecService.AccountResponse.Account] = []
    @State private var selectedSourceAccount: String?
    @State private var selectedDestinationAccount: String?
    
    // Goal data
    @State private var goals: [GoalItem] = []
    @State private var selectedGoal: GoalItem?
    
    // Transfer details
    @State private var amount: String = ""
    @State private var myReference: String = ""
    @State private var theirReference: String = ""
    @State private var transferType: TransferType = .betweenAccounts
    
    enum TransferType {
        case betweenAccounts
        case toBeneficiary
    }
    
    private var isFormValid: Bool {
        guard let source = selectedSourceAccount,
              (transferType == .betweenAccounts ? selectedDestinationAccount != nil : true),
              !source.isEmpty,
              let amountValue = Double(amount),
              amountValue > 0,
              !myReference.isEmpty else {
            return false
        }
        return true
    }
    
    var body: some View {
        VStack {
            // Header with back button
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
                
                Spacer()
                
                Text("Transfer Money")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                Circle()
                    .frame(width: 34, height: 34)
                    .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Simple hero section
                    VStack(spacing: 10) {
                        Image(systemName: "arrow.left.arrow.right.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.cyan)
                        
                        Text("Link transfers to goals")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.top, 10)
                    
                    // Main form card
                    VStack(spacing: 18) {
                        // Transfer Type
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Transfer Type")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                            
                            Picker("Transfer Type", selection: $transferType) {
                                Text("Between My Accounts").tag(TransferType.betweenAccounts)
                                Text("To Beneficiary").tag(TransferType.toBeneficiary)
                            }
                            .pickerStyle(.segmented)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                        
                        // From Account
                        AccountPickerView(
                            title: "From Account",
                            icon: "minus.circle.fill",
                            iconColor: .red,
                            selectedAccountId: $selectedSourceAccount,
                            accounts: accounts,
                            isLoading: accounts.isEmpty
                        )
                        .onChange(of: selectedSourceAccount) { _ in
                            Task {
                                await loadGoals()
                            }
                        }
                        
                        // To Account (if between accounts)
                        if transferType == .betweenAccounts {
                            AccountPickerView(
                                title: "To Account",
                                icon: "plus.circle.fill",
                                iconColor: .green,
                                selectedAccountId: $selectedDestinationAccount,
                                accounts: accounts.filter { $0.accountId != selectedSourceAccount },
                                isLoading: accounts.isEmpty
                            )
                            .onChange(of: selectedDestinationAccount) { _ in
                                Task {
                                    await loadGoals()
                                }
                            }
                        }
                        
                        // Amount
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Amount")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                            
                            HStack(spacing: 12) {
                                Text("R")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.orange)
                                    .frame(width: 30)
                                
                                TextField("0.00", text: $amount)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .keyboardType(.decimalPad)
                                    .foregroundColor(.white)
                                    .onChange(of: amount) { newValue in
                                        let filtered = newValue.filter { "0123456789.".contains($0) }
                                        if filtered != newValue {
                                            amount = filtered
                                        }
                                    }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(
                                                amount.isEmpty ? .white.opacity(0.3) : .orange.opacity(0.6),
                                                lineWidth: 1
                                            )
                                    )
                            )
                        }
                        
                        // Goal Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Link to Goal (Optional)")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                            
                            if goals.isEmpty {
                                Text("No goals available")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            } else {
                                Menu {
                                    Button("No goal (regular transfer)") {
                                        selectedGoal = nil
                                    }
                                    
                                    ForEach(goals) { goal in
                                        Button(action: {
                                            selectedGoal = goal
                                        }) {
                                            HStack {
                                                Image(systemName: "target")
                                                Text(goal.name)
                                                if selectedGoal?.id == goal.id {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.green)
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "target")
                                            .foregroundColor(.purple)
                                            .font(.system(size: 16))
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(selectedGoal?.name ?? "No goal selected")
                                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                                .foregroundColor(.white)
                                            
                                            if let goal = selectedGoal {
                                                Text("R\(String(format: "%.0f", goal.saved)) / R\(String(format: "%.0f", goal.target))")
                                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                                    .foregroundColor(.purple.opacity(0.8))
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.purple)
                                            .font(.system(size: 14))
                                    }
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.ultraThinMaterial)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .strokeBorder(
                                                        selectedGoal == nil ? .white.opacity(0.3) : .purple.opacity(0.6),
                                                        lineWidth: 1
                                                    )
                                            )
                                    )
                                }
                            }
                        }
                        
                        // References
                        VStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("My Reference")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.9))
                                
                                TextField("Reference on your statement", text: $myReference)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(.ultraThinMaterial)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Their Reference")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.9))
                                
                                TextField("Reference on recipient's statement", text: $theirReference)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(.ultraThinMaterial)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                    .foregroundColor(.white)
                            }
                        }
                        
                        // Transfer Button
                        Button(action: {
                            Task { await performTransfer() }
                        }) {
                            HStack(spacing: 10) {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.9)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                
                                Text(isLoading ? "Processing..." : "Execute Transfer")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(18)
                            .background(
                                LinearGradient(
                                    colors: isFormValid && !isLoading ?
                                        [.orange, .red] :
                                        [.gray.opacity(0.6), .gray.opacity(0.4)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(
                                color: isFormValid && !isLoading ? .orange.opacity(0.3) : .clear,
                                radius: 8,
                                y: 4
                            )
                        }
                        .disabled(!isFormValid || isLoading)
                        .scaleEffect(isFormValid && !isLoading ? 1.0 : 0.98)
                        .animation(.easeInOut(duration: 0.2), value: isFormValid)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            
            // Success overlay
            if showSuccessOverlay {
                SuccessOverlay(
                    isShowing: $showSuccessOverlay,
                    message: createSuccessMessage(),
                    isOutgoing: isOutgoingTransfer,
                    onComplete: { dismiss() }
                )
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
            Task { await loadInitialData() }
        }
    }
    
    // MARK: - Data Loading and Transfer Logic
    private func loadInitialData() async {
        await loadAccounts()
        await loadGoals()
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
                if let firstAccount = fetchedAccounts.first {
                    self.selectedSourceAccount = firstAccount.accountId
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load accounts: \(error.localizedDescription)"
            }
        }
    }
    
    private func loadGoals() async {
        // Always clear goals before fetching new ones
        await MainActor.run {
            self.goals = []
            self.selectedGoal = nil
        }
        
        // Create a set of account IDs to fetch goals for
        var accountIds = Set<String>()
        if let source = selectedSourceAccount {
            accountIds.insert(source)
        }
        if let destination = selectedDestinationAccount, transferType == .betweenAccounts {
            accountIds.insert(destination)
        }
        
        guard !accountIds.isEmpty else {
            return
        }
        
        do {
            // Fetch goals for all relevant accounts in parallel
            let allGoals = try await withThrowingTaskGroup(of: [GoalItem].self) { group in
                for accountId in accountIds {
                    group.addTask {
                        try await self.appwriteService.fetchGoals(for: accountId)
                    }
                }
                
                var combinedGoals: [GoalItem] = []
                for try await goalList in group {
                    combinedGoals.append(contentsOf: goalList)
                }
                return combinedGoals
            }
            
            // Remove duplicates and update the UI
            let uniqueGoals = Array(Set(allGoals))
            
            await MainActor.run {
                self.goals = uniqueGoals.sorted { $0.name < $1.name }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load goals: \(error.localizedDescription)"
            }
        }
    }
    
    private func performTransfer() async {
        guard isFormValid,
              let sourceAccountId = selectedSourceAccount,
              let amountValue = Double(amount),
              amountValue > 0 else {
            await MainActor.run {
                self.errorMessage = "Please fill out all fields correctly."
            }
            return
        }
        
        if appwriteService.isGuestMode {
            // Simulate a sandbox transfer
            await MainActor.run {
                self.isLoading = true
                self.errorMessage = nil
                self.successMessage = nil
            }
            
            // Simulate a delay
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            // Simulate a successful transfer
            await MainActor.run {
                self.isLoading = false
                self.isOutgoingTransfer = true // Or determine based on logic
                self.showSuccessOverlay = true
            }
            return
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
            self.successMessage = nil
        }
        
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
            
            var myRef = myReference
            var theirRef = theirReference
            
            if let goal = selectedGoal {
                if !myRef.contains(goal.name) {
                    myRef = "from-\(sourceAccountId)-\(goal.name)"
                }
                if !theirRef.contains(goal.name) {
                    theirRef = "to-\(selectedDestinationAccount ?? "")"
                }
            }
            
            if transferType == .betweenAccounts {
                guard let destinationAccountId = selectedDestinationAccount else {
                    return
                }
                
                let transferResult = try await InvestecService.shared.transferBetweenAccounts(
                    apiKey: apiKey,
                    clientId: clientId,
                    clientSecret: clientSecret,
                    sourceAccountId: sourceAccountId,
                    destinationAccountId: destinationAccountId,
                    amount: amountValue,
                    myReference: myRef,
                    theirReference: theirRef
                )
                
                if let goal = selectedGoal {
                    let isOutgoing = determineTransferDirection(
                        goal: goal,
                        sourceAccountId: sourceAccountId,
                        destinationAccountId: selectedDestinationAccount
                    )
                    try await updateGoalProgress(goal: goal, amount: amountValue, isOutgoingTransfer: isOutgoing)
                    
                    self.isOutgoingTransfer = isOutgoing
                }
                
                await MainActor.run {
                    self.successMessage = "Transfer completed successfully"
                    self.isLoading = false
                    self.transferAmount = String(format: "%.2f", amountValue)
                    
                    self.amount = ""
                    self.myReference = ""
                    self.theirReference = ""
                    
                    withAnimation {
                        self.showSuccessOverlay = true
                    }
                }
            }
            
            await loadGoals()
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Transfer error: \(error.localizedDescription)"
                print("Transfer error response: ", error)
            }
        }
    }
    
    private func updateGoalProgress(goal: GoalItem, amount: Double, isOutgoingTransfer: Bool) async throws {
        let adjustedAmount = isOutgoingTransfer ? -amount : amount
        let newSavedAmount = max(0, goal.saved + adjustedAmount)
        
        try await appwriteService.databases.updateDocument(
            databaseId: appwriteService.databaseId,
            collectionId: appwriteService.goalsCollectionId,
            documentId: goal.id,
            data: [
                "saved_amount": newSavedAmount
            ]
        )
        
        let direction = isOutgoingTransfer ? "withdrawn" : "added"
        print("Updated goal '\(goal.name)' - \(direction) R\(amount), new total: R\(newSavedAmount)")
    }
    
    private func determineTransferDirection(goal: GoalItem, sourceAccountId: String, destinationAccountId: String?) -> Bool {
        guard let goalLinkedAccountId = goal.linkedAccountId else {
            return true
        }
        
        if sourceAccountId == goalLinkedAccountId {
            return true
        }
        
        if destinationAccountId == goalLinkedAccountId {
            return false
        }
        
        return true
    }
    
    private func createSuccessMessage() -> String {
        guard let goal = selectedGoal else {
            return "Transfer of R\(transferAmount) completed successfully!"
        }
        
        let direction = isOutgoingTransfer ? "-" : "+"
        return "Goal '\(goal.name)' updated: \(direction)R\(transferAmount)"
    }
}

// MARK: - Custom Components

struct AccountPickerView: View {
    let title: String
    let icon: String
    let iconColor: Color
    @Binding var selectedAccountId: String?
    let accounts: [InvestecService.AccountResponse.Account]
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
            
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(.cyan)
                        .scaleEffect(0.9)
                    Spacer()
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            } else {
                Menu {
                    ForEach(accounts, id: \.accountId) { account in
                        Button(action: {
                            withAnimation {
                                selectedAccountId = account.accountId
                            }
                        }) {
                            HStack {
                                Image(systemName: "creditcard.fill")
                                Text(account.displayName)
                                if selectedAccountId == account.accountId {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: icon)
                            .foregroundColor(iconColor)
                            .font(.system(size: 18))
                        
                        Text(selectedAccountId != nil ?
                             accounts.first(where: { $0.accountId == selectedAccountId })?.displayName ?? "Select account" :
                             "Select account")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .foregroundColor(iconColor)
                            .font(.system(size: 16))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        selectedAccountId == nil ? .white.opacity(0.3) : iconColor.opacity(0.6),
                                        lineWidth: 1
                                    )
                            )
                    )
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        StunningTransferView()
            .environmentObject(AppwriteService.shared)
    }
}
