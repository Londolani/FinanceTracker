import SwiftUI
import Appwrite

struct TransferView: View {
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
    
    // Form validation
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
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    headerView
                    
                    if isLoading {
                        loadingView
                    } else {
                        formContent
                    }
                }
            }
            .navigationTitle("Transfer & Goals")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task {
                    await loadInitialData()
                }
            }
            
            // Success overlay with confetti
            if showSuccessOverlay {
                SuccessOverlay(
                    isShowing: $showSuccessOverlay,
                    message: createSuccessMessage(),
                    isOutgoing: isOutgoingTransfer,
                    onComplete: {
                        dismiss()
                    }
                )
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        Group {
            Text("Link Transaction to Goal")
                .font(.largeTitle)
                .bold()
            
            Text("When you make a transfer, you can link it to a goal to track your progress.")
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .padding()
            Text("Processing transaction...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private var formContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            sourceAccountPicker
            
            transferTypePicker
            
            if transferType == .betweenAccounts {
                destinationAccountPicker
            }
            
            goalPicker
            
            goalDetailsView
            
            amountTextField
            
            referencesSection
            
            statusMessages
            
            submitButton
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var sourceAccountPicker: some View {
        VStack(alignment: .leading) {
            Text("From Account")
                .font(.headline)
            
            if accounts.isEmpty {
                Text("Loading accounts...")
                    .foregroundColor(.secondary)
            } else {
                let accountOptions = accounts.map { AccountOption(id: $0.accountId, name: $0.displayName) }
                Picker("Select source account", selection: $selectedSourceAccount) {
                    Text("Select account").tag(nil as String?)
                    ForEach(accountOptions) { option in
                        Text(option.name).tag(option.id as String?)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
    
    private var transferTypePicker: some View {
        Picker("Transfer Type", selection: $transferType) {
            Text("Between My Accounts").tag(TransferType.betweenAccounts)
            Text("To Beneficiary").tag(TransferType.toBeneficiary)
        }
        .pickerStyle(.segmented)
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var destinationAccountPicker: some View {
        VStack(alignment: .leading) {
            Text("To Account")
                .font(.headline)
            
            if accounts.isEmpty {
                Text("Loading accounts...")
                    .foregroundColor(.secondary)
            } else {
                let destinationOptions = accounts.filter { $0.accountId != selectedSourceAccount }.map { AccountOption(id: $0.accountId, name: $0.displayName) }
                Picker("Select destination account", selection: $selectedDestinationAccount) {
                    Text("Select account").tag(nil as String?)
                    ForEach(destinationOptions) { option in
                        Text(option.name).tag(option.id as String?)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
    
    @ViewBuilder
    private var goalPicker: some View {
        VStack(alignment: .leading) {
            Text("Link to Goal")
                .font(.headline)
            
            if goals.isEmpty {
                Text("Loading goals...")
                    .foregroundColor(.secondary)
            } else {
                Picker("Select goal", selection: $selectedGoal) {
                    Text("No goal (regular transfer)").tag(nil as GoalItem?)
                    ForEach(goals) { goal in
                        Text(goal.name)
                            .tag(goal as GoalItem?)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
    
    @ViewBuilder
    private var goalDetailsView: some View {
        if let goal = selectedGoal {
            VStack(alignment: .leading, spacing: 8) {
                Text("Goal: \(goal.name)")
                    .font(.headline)
                
                HStack {
                    Text("Target:")
                    Spacer()
                    Text("R\(String(format: "%.2f", goal.target))")
                        .bold()
                }
                
                HStack {
                    Text("Current progress:")
                    Spacer()
                    Text("R\(String(format: "%.2f", goal.saved))")
                        .bold()
                }
                
                ProgressBar(value: goal.saved, total: goal.target)
                    .frame(height: 8)
                    .padding(.vertical, 4)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
        }
    }
    
    private var amountTextField: some View {
        VStack(alignment: .leading) {
            Text("Amount")
                .font(.headline)
            
            TextField("0.00", text: $amount)
                .keyboardType(.decimalPad)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .onChange(of: amount) { newValue in
                    let filtered = newValue.filter { "0123456789.".contains($0) }
                    if filtered != newValue {
                        amount = filtered
                    }
                }
        }
    }
    
    private var referencesSection: some View {
        Group {
            VStack(alignment: .leading) {
                Text("My Reference")
                    .font(.headline)
                
                TextField("Reference on your statement", text: $myReference)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .onChange(of: selectedGoal) { newGoal in
                        updateReference(for: newGoal)
                    }
            }
            
            VStack(alignment: .leading) {
                Text("Their Reference")
                    .font(.headline)
                
                TextField("Reference on recipient's statement", text: $theirReference)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .onChange(of: selectedGoal) { newGoal in
                        updateReference(for: newGoal)
                    }
            }
        }
    }
    
    @ViewBuilder
    private var statusMessages: some View {
        if let errorMessage = errorMessage {
            Text(errorMessage)
                .foregroundColor(.red)
                .padding()
        }
        
        if let successMessage = successMessage {
            Text(successMessage)
                .foregroundColor(.green)
                .padding()
        }
    }
    
    private var submitButton: some View {
        Button(action: {
            Task {
                await performTransfer()
            }
        }) {
            Text("Execute Transfer")
                .frame(maxWidth: .infinity)
                .padding()
                .background(isFormValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .disabled(!isFormValid || isLoading)
        .padding()
    }
    
    // MARK: - Data Loading
    
    private func loadInitialData() async {
        await loadAccounts()
        await loadGoals()
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
                throw NSError(domain: "TransferView", code: 400, userInfo: [
                    NSLocalizedDescriptionKey: "No Investec credentials found. Please add your API credentials first."
                ])
            }
            
            // Get accounts
            let accounts = try await InvestecService.shared.getAccounts(
                apiKey: apiKey,
                clientId: clientId,
                clientSecret: clientSecret
            )
            
            await MainActor.run {
                self.accounts = accounts
                if let firstAccount = accounts.first {
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
        do {
            guard let userId = appwriteService.currentUser?.id else {
                throw NSError(domain: "TransferView", code: 401, userInfo: [
                    NSLocalizedDescriptionKey: "User not authenticated"
                ])
            }
            
            let goalsList = try await appwriteService.databases.listDocuments(
                databaseId: appwriteService.databaseId,
                collectionId: appwriteService.goalsCollectionId
            )
            
            let items: [GoalItem] = goalsList.documents.compactMap { doc in
                let data = doc.data
                let name = (data["name"]?.value as? String) ?? "Unnamed Goal"
                let target = (data["target_amount"]?.value as? Double) ?? ((data["target_amount"]?.value as? NSNumber)?.doubleValue ?? 0)
                let saved = (data["saved_amount"]?.value as? Double) ?? ((data["saved_amount"]?.value as? NSNumber)?.doubleValue ?? 0)
                let isTracked = (data["is_tracked"]?.value as? Bool) ?? true
                
                return GoalItem(id: doc.id, name: name, target: target, saved: saved, isTracked: isTracked)
            }
            
            await MainActor.run {
                self.goals = items
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load goals: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Actions
    
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
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
            self.successMessage = nil
        }
        
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
                throw NSError(domain: "TransferView", code: 400, userInfo: [
                    NSLocalizedDescriptionKey: "No Investec credentials found. Please add your API credentials first."
                ])
            }
            
            // Format references with goal information
            var myRef = myReference
            var theirRef = theirReference
            
            if let goal = selectedGoal {
                // Add goal tag if not already present
                if !myRef.contains("[\(goal.name)]") {
                    myRef = "[\(goal.name)] \(myRef)"
                }
                if !theirRef.contains("[\(goal.name)]") {
                    theirRef = "[\(goal.name)] \(theirRef)"
                }
            }
            
            // Execute the transfer
            let transferResult: InvestecService.TransferResponse.TransferResult
            
            if transferType == .betweenAccounts {
                guard let destinationAccountId = selectedDestinationAccount else {
                    throw NSError(domain: "TransferView", code: 400, userInfo: [
                        NSLocalizedDescriptionKey: "Please select a destination account."
                    ])
                }
                
                transferResult = try await InvestecService.shared.transferBetweenAccounts(
                    apiKey: apiKey,
                    clientId: clientId,
                    clientSecret: clientSecret,
                    sourceAccountId: sourceAccountId,
                    destinationAccountId: destinationAccountId,
                    amount: amountValue,
                    myReference: myRef,
                    theirReference: theirRef
                )
            } else {
                // For beneficiary payments (would need to implement beneficiary selection)
                throw NSError(domain: "TransferView", code: 400, userInfo: [
                    NSLocalizedDescriptionKey: "Beneficiary payments not yet implemented."
                ])
            }
            
            // Update goal progress if a goal was selected
            if let goal = selectedGoal {
                // Determine if this is an outgoing transfer (money leaving the selected account)
                let isOutgoing = true // For now, all transfers from the source account are outgoing
                try await updateGoalProgress(goal: goal, amount: amountValue, isOutgoingTransfer: isOutgoing)
            }
            
            // Handle successful transfer
            await MainActor.run {
                self.successMessage = "Transfer completed successfully: \(transferResult.description)"
                self.isLoading = false
                
                // Store transfer details for success overlay
                self.transferAmount = String(format: "%.2f", amountValue)
                self.isOutgoingTransfer = true
                
                // Reset form
                self.amount = ""
                if let goal = selectedGoal {
                    self.myReference = myRef.replacingOccurrences(of: "[\(goal.name)] ", with: "")
                    self.theirReference = theirRef.replacingOccurrences(of: "[\(goal.name)] ", with: "")
                } else {
                    self.myReference = ""
                    self.theirReference = ""
                }
                
                // Show success overlay
                withAnimation {
                    self.showSuccessOverlay = true
                }
                
                // Navigate back to main screen after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    dismiss()
                }
            }
            
            // Reload goals to show updated progress
            await loadGoals()
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Transfer failed: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func updateGoalProgress(goal: GoalItem, amount: Double, isOutgoingTransfer: Bool) async throws {
        // Calculate new saved amount based on transfer direction
        let adjustedAmount = isOutgoingTransfer ? -amount : amount
        let newSavedAmount = max(0, goal.saved + adjustedAmount) // Ensure it doesn't go below 0
        
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
    
    // MARK: - Helper Functions
    
    private func updateReference(for goal: GoalItem?) {
        guard let sourceAccountId = selectedSourceAccount,
              let sourceAccount = accounts.first(where: { $0.accountId == sourceAccountId }) else {
            myReference = "Transfer"
            theirReference = "Transfer"
            return
        }
        
        let fromPart = "from-\(sourceAccount.accountNumber ?? sourceAccount.accountId)"
        
        if let goal = goal {
            myReference = "\(fromPart)-\(goal.name.replacingOccurrences(of: " ", with: "_"))"
        } else {
            myReference = fromPart
        }
        
        if let destAccountId = selectedDestinationAccount,
           let destAccount = accounts.first(where: { $0.accountId == destAccountId }) {
            theirReference = "to-\(destAccount.accountNumber ?? destAccount.accountId)"
        } else {
            theirReference = "Payment"
        }
    }
    
    private func createSuccessMessage() -> String {
        guard let goal = selectedGoal else {
            return "Transfer of R\(transferAmount) completed successfully!"
        }
        
        return "Goal '\(goal.name)' updated: +R\(transferAmount)"
    }
}

struct ProgressBar: View {
    let value: Double
    let total: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .opacity(0.3)
                    .foregroundColor(.gray)
                
                Rectangle()
                    .frame(width: min(CGFloat(self.value / self.total) * geometry.size.width, geometry.size.width), height: geometry.size.height)
                    .foregroundColor(.blue)
            }
            .cornerRadius(45)
        }
    }
}

private struct AccountOption: Identifiable, Equatable {
    let id: String
    let name: String
}

#Preview {
    NavigationView {
        TransferView()
            .environmentObject(AppwriteService.shared)
    }
}
