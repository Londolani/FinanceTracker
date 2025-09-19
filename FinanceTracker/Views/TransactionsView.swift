import SwiftUI
import Appwrite

struct TransactionsView: View {
    @EnvironmentObject var appwriteService: AppwriteService
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var transactions: [Transaction] = []
    @State private var selectedAccountId: String?
    @State private var accounts: [InvestecService.AccountResponse.Account] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header section
            headerSection
            
            // Main content
            ZStack {
                LinearGradient(
                    colors: [.blue.opacity(0.05), .purple.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Account selector card (if multiple accounts)
                        if accounts.count > 1 {
                            accountSelectorCard
                        }
                        
                        // Transactions content
                        transactionsContent
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await loadTransactions()
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
                
                Text("Recent Transactions")
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
    
    private var accountSelectorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                
                Text("Select Account")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Menu {
                ForEach(accounts, id: \.accountId) { account in
                    Button(action: {
                        selectedAccountId = account.accountId
                        Task { await loadTransactions() }
                    }) {
                        HStack {
                            Text(account.displayName)
                            if selectedAccountId == account.accountId {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(accounts.first { $0.accountId == selectedAccountId }?.displayName ?? "Select account")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.blue.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private var transactionsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let errorMessage = errorMessage {
                errorCard(message: errorMessage)
            }
            
            if isLoading {
                loadingCard
            } else if transactions.isEmpty {
                emptyStateCard
            } else {
                transactionsList
            }
        }
    }
    
    private var loadingCard: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading your transactions...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var emptyStateCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "creditcard")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))
            
            Text("No Transactions Found")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.secondary)
            
            Text("Connect your Investec account or check back later for transaction history.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private func errorCard(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(message)
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
    
    private var transactionsList: some View {
        LazyVStack(spacing: 8) {
            ForEach(transactions) { transaction in
                StunningTransactionCard(transaction: transaction)
            }
        }
    }
    
    private func loadTransactions() async {
        await MainActor.run { 
            isLoading = true
            errorMessage = nil 
        }
        
        do {
            // First, fetch the saved credentials from Appwrite
            let credentialsList = try await appwriteService.databases.listDocuments(
                databaseId: appwriteService.databaseId,
                collectionId: appwriteService.credentialsCollectionId
            )
            
            // Check if we have credentials
            guard let doc = credentialsList.documents.first,
                  let apiKey = doc.data["investec_api_key"]?.value as? String,
                  let clientId = doc.data["client_id"]?.value as? String,
                  let clientSecret = doc.data["client_secret"]?.value as? String else {
                throw NSError(domain: "TransactionsView", code: 400, userInfo: [
                    NSLocalizedDescriptionKey: "No Investec credentials found. Please add your API credentials first."
                ])
            }
            
            // Get accounts if we don't have them yet
            if accounts.isEmpty {
                self.accounts = try await InvestecService.shared.getAccounts(
                    apiKey: apiKey,
                    clientId: clientId,
                    clientSecret: clientSecret
                )
                
                // Set the first account as default if not already set
                if selectedAccountId == nil, let firstAccount = accounts.first {
                    selectedAccountId = firstAccount.accountId
                }
            }
            
            // Ensure we have an account selected
            guard let accountId = selectedAccountId else {
                throw NSError(domain: "TransactionsView", code: 400, userInfo: [
                    NSLocalizedDescriptionKey: "No account selected or available."
                ])
            }
            
            // Get date range for last 30 days
            let dates = InvestecService.shared.getLast30DaysDateStrings()
            
            // Fetch transactions from Investec API
            let investecTransactions = try await InvestecService.shared.getTransactions(
                accountId: accountId,
                fromDate: dates.from,
                toDate: dates.to,
                apiKey: apiKey,
                clientId: clientId,
                clientSecret: clientSecret
            )
            
            // Convert to our app's transaction model
            let items: [Transaction] = investecTransactions.map { transaction in
                return Transaction(
                    id: transaction.id,
                    accountId: transaction.accountId,
                    type: transaction.type,
                    transactionType: transaction.transactionType,
                    status: transaction.status,
                    description: transaction.description,
                    amount: transaction.amount,
                    currency: transaction.currency,
                    postingDate: transaction.postingDate,
                    valueDate: transaction.valueDate,
                    transactionDate: transaction.transactionDate,
                    actionDate: transaction.actionDate,
                    category: transaction.category,
                    cardNumber: transaction.cardNumber,
                    runningBalance: transaction.runningBalance,
                    postedOrder: transaction.postedOrder
                )
            }
            
            await MainActor.run {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                
                self.transactions = items.sorted(by: { t1, t2 in
                    let date1 = t1.transactionDate.flatMap { dateFormatter.date(from: $0) } ?? Date.distantPast
                    let date2 = t2.transactionDate.flatMap { dateFormatter.date(from: $0) } ?? Date.distantPast
                    return date1 > date2
                })
                self.isLoading = false
            }
        } catch {
            await MainActor.run { 
                self.errorMessage = "Failed to load transactions: \(error.localizedDescription)"
                self.isLoading = false 
            }
        }
    }
}

struct StunningTransactionCard: View {
    let transaction: Transaction

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private var transactionDate: Date? {
        guard let dateString = transaction.transactionDate else { return nil }
        return Self.dateFormatter.date(from: dateString)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Transaction header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.description)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if let date = transactionDate {
                        Text(date, style: .date)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(transaction.amount < 0 ? "-R\(format(abs(transaction.amount)))" : "+R\(format(transaction.amount))")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(transaction.amount < 0 ? .red : .green)
                    
                    if let balance = transaction.runningBalance {
                        Text("Balance: R\(format(balance))")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }
    
    private func format(_ value: Double) -> String {
        NumberFormatter.currency.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}

#Preview {
    NavigationView {
        TransactionsView()
            .environmentObject(AppwriteService.shared)
    }
}
