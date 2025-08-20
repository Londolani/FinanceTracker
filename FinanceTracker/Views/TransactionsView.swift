import SwiftUI
import Appwrite

struct TransactionsView: View {
    @EnvironmentObject var appwriteService: AppwriteService
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var transactions: [TransactionItem] = []
    @State private var selectedAccountId: String?
    @State private var accounts: [InvestecService.AccountResponse.Account] = []

    var body: some View {
        ZStack {
            LinearGradient(colors: [.green.opacity(0.1), .teal.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 16) {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                if isLoading {
                    ProgressView("Loading transactions...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if transactions.isEmpty {
                    ContentUnavailableView(
                        "No Transactions",
                        systemImage: "creditcard",
                        description: Text("Connect your Investec account or wait for transaction sync.")
                    )
                } else {
                    // Account picker if multiple accounts
                    if accounts.count > 1 {
                        Picker("Select Account", selection: $selectedAccountId) {
                            ForEach(accounts, id: \.accountId) { account in
                                Text(account.accountName)
                                    .tag(account.accountId as String?)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal)
                        .onChange(of: selectedAccountId) { _ in
                            Task {
                                await loadTransactions()
                            }
                        }
                    }
                    
                    List(transactions) { transaction in
                        TransactionRow(transaction: transaction)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .listStyle(.plain)
                    .background(Color.clear)
                    .refreshable {
                        await loadTransactions()
                    }
                }
            }
        }
        .task { await loadTransactions() }
        .navigationTitle("Recent Transactions")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func TransactionRow(transaction: TransactionItem) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Circle()
                .fill(transaction.isDebit ? .red.opacity(0.2) : .green.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: transaction.isDebit ? "arrow.down" : "arrow.up")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(transaction.isDebit ? .red : .green)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.headline)
                    .lineLimit(2)
                
                if let date = transaction.date {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(transaction.dateString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.isDebit ? "-R\(format(abs(transaction.amount)))" : "+R\(format(transaction.amount))")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(transaction.isDebit ? .red : .green)
                
                if let balance = transaction.runningBalance {
                    Text("Balance: R\(format(balance))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(transaction.isDebit ? "Debit" : "Credit")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(transaction.isDebit ? .red.opacity(0.1) : .green.opacity(0.1))
                    .foregroundColor(transaction.isDebit ? .red : .green)
                    .cornerRadius(8)
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
    
    private func format(_ value: Double) -> String {
        NumberFormatter.currency.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
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
                apiKey: apiKey,
                clientId: clientId,
                clientSecret: clientSecret,
                accountId: accountId,
                fromDate: dates.from,
                toDate: dates.to
            )
            
            // Convert to our app's transaction model
            let items: [TransactionItem] = investecTransactions.map { transaction in
                // Handle transaction date parsing
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let date = dateFormatter.date(from: transaction.date)
                
                return TransactionItem(
                    id: transaction.id,
                    description: transaction.description,
                    amount: transaction.amount,
                    dateString: transaction.date,
                    date: date,
                    runningBalance: transaction.runningBalance
                )
            }
            
            await MainActor.run { 
                self.transactions = items.sorted(by: { 
                    ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast)
                }).prefix(5).map { $0 } // Take the 5 most recent transactions
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

struct TransactionItem: Identifiable {
    let id: String
    let description: String
    let amount: Double
    let dateString: String
    let date: Date?
    let runningBalance: Double?
    
    var isDebit: Bool { amount < 0 }
    
    init(id: String, description: String, amount: Double, dateString: String = "", date: Date? = nil, runningBalance: Double? = nil) {
        self.id = id
        self.description = description
        self.amount = amount
        self.dateString = dateString
        self.date = date
        self.runningBalance = runningBalance
    }
}

#Preview {
    NavigationView {
        TransactionsView()
            .environmentObject(AppwriteService.shared)
    }
}
