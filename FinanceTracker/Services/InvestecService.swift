import Foundation
import Combine

class InvestecService: ObservableObject {
    static let shared = InvestecService()
    
    private var accessToken: String?
    private var expiresAt: Date?
    
    // Investec API endpoints
    private let baseURL = "https://openapi.investec.com"
    private let tokenURL = "https://openapi.investec.com/identity/v2/oauth2/token"
    
    // Fallback sandbox data for guest mode
    private let sandboxAccounts: [AccountResponse.Account] = [
        AccountResponse.Account(
            accountId: "sandbox_account_1",
            accountNumber: "123456789",
            accountName: "Demo Checking",
            referenceName: "Demo Account",
            productName: "Checking Account",
            kycCompliant: true,
            profileId: "sandbox_profile_1",
            profileName: "Demo Profile"
        ),
        AccountResponse.Account(
            accountId: "sandbox_account_2",
            accountNumber: "987654321",
            accountName: "Demo Savings",
            referenceName: "Savings Account",
            productName: "Savings Account",
            kycCompliant: true,
            profileId: "sandbox_profile_2",
            profileName: "Demo Profile"
        )
    ]
    
    private let sandboxTransactions: [Transaction] = [
        Transaction(
            id: "sandbox_txn_1",
            accountId: "sandbox_account_1",
            type: "Credit",
            transactionType: "Deposits",
            status: "POSTED",
            description: "Salary Deposit",
            amount: 5000.00,
            currency: "ZAR",
            postingDate: "2025-08-30",
            valueDate: "2025-08-30",
            transactionDate: "2025-08-30",
            actionDate: "2025-09-15",
            category: "Income",
            cardNumber: nil,
            runningBalance: 12500.00,
            postedOrder: 4752
        ),
        Transaction(
            id: "sandbox_txn_2",
            accountId: "sandbox_account_1",
            type: "Debit",
            transactionType: "CardPurchases",
            status: "POSTED",
            description: "Grocery Shopping - Woolworths",
            amount: -150.00,
            currency: "ZAR",
            postingDate: "2025-08-26",
            valueDate: "2025-08-31",
            transactionDate: "2025-08-23",
            actionDate: "2025-09-15",
            category: "Groceries",
            cardNumber: "402167xxxxxx5069",
            runningBalance: 12350.00,
            postedOrder: 4742
        ),
        Transaction(
            id: "sandbox_txn_3",
            accountId: "sandbox_account_1",
            type: "Debit",
            transactionType: "ATMWithdrawals",
            status: "POSTED",
            description: "SUNNINGHILL SQUARE SANDTON ZA",
            amount: -200.00,
            currency: "ZAR",
            postingDate: "2025-08-31",
            valueDate: "2025-08-31",
            transactionDate: "2025-08-31",
            actionDate: "2025-09-15",
            category: "Transport",
            cardNumber: "402167xxxxxx5092",
            runningBalance: 12270.00,
            postedOrder: 4755
        ),
        Transaction(
            id: "sandbox_txn_4",
            accountId: "sandbox_account_1",
            type: "Debit",
            transactionType: "PayShap",
            status: "POSTED",
            description: "LONDOLANI CAPITEC",
            amount: -45.00,
            currency: "ZAR",
            postingDate: "2025-08-28",
            valueDate: "2025-08-27",
            transactionDate: "2025-08-27",
            actionDate: "2025-09-15",
            category: "Dining",
            cardNumber: "",
            runningBalance: 12225.00,
            postedOrder: 4750
        ),
        Transaction(
            id: "sandbox_txn_5",
            accountId: "sandbox_account_2",
            type: "Credit",
            transactionType: "Deposits",
            status: "POSTED",
            description: "Transfer from Checking",
            amount: 1000.00,
            currency: "ZAR",
            postingDate: "2025-08-28",
            valueDate: "2025-08-28",
            transactionDate: "2025-08-28",
            actionDate: "2025-09-15",
            category: "Transfers",
            cardNumber: "",
            runningBalance: 8500.00,
            postedOrder: 4751
        ),
        Transaction(
            id: "sandbox_txn_6",
            accountId: "sandbox_account_2",
            type: "Credit",
            transactionType: "Deposits",
            status: "POSTED",
            description: "Interest Payment",
            amount: 25.50,
            currency: "ZAR",
            postingDate: "2025-08-27",
            valueDate: "2025-08-27",
            transactionDate: "2025-08-27",
            actionDate: "2025-09-15",
            category: "Income",
            cardNumber: "",
            runningBalance: 8525.50,
            postedOrder: 4747
        )
    ]
    
    // MARK: - Models
    
    struct TransactionResponse: Codable {
        let data: TransactionData
        
        struct TransactionData: Codable {
            var transactions: [Transaction]
        }
    }
    
    struct AccountResponse: Codable {
        let data: AccountData
        
        struct AccountData: Codable {
            let accounts: [Account]
        }
        
        struct Account: Codable {
            let accountId: String
            let accountNumber: String
            let accountName: String
            let referenceName: String
            let productName: String?
            let kycCompliant: Bool?
            let profileId: String?
            let profileName: String?
            
            // Computed property for display in UI
            var displayName: String {
                return "\(accountName) (\(accountNumber))"
            }
        }
    }
    
    // New models for transfer functionality
    struct TransferRequest: Codable {
        let transferList: [Transfer]
        
        struct Transfer: Codable {
            let beneficiaryAccountId: String
            let amount: String
            let myReference: String
            let theirReference: String
        }
    }
    
    struct TransferResponse: Codable {
        let data: TransferData?
        
        struct TransferData: Codable {
            let transferResponses: [TransferResult]?
            // Alternative field names that the API might use
            let TransferResponses: [TransferResult]?
            let transferResponse: TransferResponseWrapper?
            
            enum CodingKeys: String, CodingKey {
                case transferResponses
                case TransferResponses
                case transferResponse
            }
        }
        
        struct TransferResponseWrapper: Codable {
            let TransferResponses: [TransferResult]?
        }
        
        struct TransferResult: Codable {
            let status: String?
            let description: String?
            let transferId: String?
            // Alternative field names from the API
            let Status: String?
            let PaymentReferenceNumber: String?
            let PaymentDate: String?
            let BeneficiaryName: String?
            let AuthorisationRequired: Bool?
            
            enum CodingKeys: String, CodingKey {
                case status, description, transferId
                case Status, PaymentReferenceNumber, PaymentDate, BeneficiaryName, AuthorisationRequired
            }
            
            // Custom initializer for creating instances programmatically
            init(status: String?, description: String?, transferId: String?) {
                self.status = status
                self.description = description
                self.transferId = transferId
                self.Status = nil
                self.PaymentReferenceNumber = nil
                self.PaymentDate = nil
                self.BeneficiaryName = nil
                self.AuthorisationRequired = nil
            }
            
            var finalStatus: String {
                return status ?? Status ?? "Completed"
            }
            
            var finalDescription: String {
                return description ?? PaymentReferenceNumber ?? "Transfer completed successfully"
            }
        }
    }
    
    struct BeneficiaryResponse: Codable {
        let data: [Beneficiary]
        
        struct Beneficiary: Identifiable, Codable {
            let beneficiaryId: String
            let accountNumber: String
            let code: String
            let bank: String
            let beneficiaryName: String
            let name: String
            
            var id: String { beneficiaryId }
        }
    }
    
    private init() {}
    
    // Default credentials (set these to your production values if needed)
    private let currentApiKey: String = ""
    private let currentClientId: String = ""
    private let currentSecret: String = ""
    private let currentBaseURL: String = "https://openapisandbox.investec.com"
    
    // Guest mode sandbox credentials
    private let guestApiKey: String = "eUF4elFSRlg5N3ZPY3lRQXdsdUVVNkg2ZVB4TUE1ZVk6YVc1MlpYTjBaV04wWlhOdGVtRXRjR0l0WVdOamIzVnVkSE10YzJGdVpHSnZlQT09"
    private let guestClientId: String = "yAxzQRFX97vOcyQAwluEU6H6ePxMA5eY"
    private let guestSecret: String = "4dY0PjEYqoBrZ99r"
    private let guestBaseURL: String = "https://openapisandbox.investec.com"
    
    private func getAccessToken(apiKey: String? = nil, clientId: String? = nil, clientSecret: String? = nil) async throws -> String {
        // Determine which credentials and base URL to use
        let useApiKey: String
        let useClientId: String
        let useSecret: String
        let useBaseURL: String
        
        if AppwriteService.shared.isGuestMode {
            useApiKey = guestApiKey
            useClientId = guestClientId
            useSecret = guestSecret
            useBaseURL = guestBaseURL
        } else {
            guard let apiKey = apiKey, let clientId = clientId, let clientSecret = clientSecret, !apiKey.isEmpty, !clientId.isEmpty, !clientSecret.isEmpty else {
                throw NSError(domain: "InvestecAPI", code: 401, userInfo: [NSLocalizedDescriptionKey: "API credentials are required but missing."])
            }
            useApiKey = apiKey
            useClientId = clientId
            useSecret = clientSecret
            useBaseURL = baseURL
        }
        
        let useTokenURL = "\(useBaseURL)/identity/v2/oauth2/token"
        
        let credentials = "\(useClientId):\(useSecret)".data(using: .utf8)!.base64EncodedString()
        var request = URLRequest(url: URL(string: useTokenURL)!)
        request.httpMethod = "POST"
        request.addValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        request.addValue(useApiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=client_credentials&scope=accounts".data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "InvestecAPI", code: (response as? HTTPURLResponse)?.statusCode ?? 500,
                         userInfo: [NSLocalizedDescriptionKey: "Authentication failed: \(errorString)"])
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let token = json?["access_token"] as? String,
              let expiresIn = json?["expires_in"] as? Int else {
            throw NSError(domain: "InvestecAPI", code: 0,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid token response"])
        }
        self.accessToken = token
        self.expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn - 60))
        return token
    }

    func getAccounts(apiKey: String? = nil, clientId: String? = nil, clientSecret: String? = nil) async throws -> [AccountResponse.Account] {
        let token = try await getAccessToken(apiKey: apiKey, clientId: clientId, clientSecret: clientSecret)
        
        let useBaseURL = AppwriteService.shared.isGuestMode ? guestBaseURL : baseURL
        let useApiKey = AppwriteService.shared.isGuestMode ? guestApiKey : (apiKey ?? "")
        
        let url = URL(string: "\(useBaseURL)/za/pb/v1/accounts")!
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(useApiKey, forHTTPHeaderField: "x-api-key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "InvestecAPI", code: (response as? HTTPURLResponse)?.statusCode ?? 500,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to fetch accounts: \(errorString)"])
        }
        
        // Debug: Print the raw response to see what the API is returning
        if let responseString = String(data: data, encoding: .utf8) {
            print("Raw accounts response: \(responseString)")
        }
        
        do {
            let accountResponse = try JSONDecoder().decode(AccountResponse.self, from: data)
            return accountResponse.data.accounts
        } catch {
            print("Failed to decode accounts response: \(error)")
            // If decoding fails, it might be because there are no accounts.
            // Return an empty array to prevent a crash.
            return []
        }
    }

    // Fetch transactions for a specific account
    func getTransactions(accountId: String, fromDate: String, toDate: String, apiKey: String? = nil, clientId: String? = nil, clientSecret: String? = nil) async throws -> [Transaction] {
        let token = try await getAccessToken(apiKey: apiKey, clientId: clientId, clientSecret: clientSecret)
        
        let useBaseURL = AppwriteService.shared.isGuestMode ? guestBaseURL : baseURL
        let useApiKey = AppwriteService.shared.isGuestMode ? guestApiKey : (apiKey ?? "")
        
        var components = URLComponents(string: "\(useBaseURL)/za/pb/v1/accounts/\(accountId)/transactions")!
        components.queryItems = [
            URLQueryItem(name: "fromDate", value: fromDate),
            URLQueryItem(name: "toDate", value: toDate)
        ]
        
        let url = components.url!
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(useApiKey, forHTTPHeaderField: "x-api-key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Error response: \(errorString)")
            throw NSError(domain: "InvestecAPI", code: (response as? HTTPURLResponse)?.statusCode ?? 500,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to fetch transactions: \(errorString)"])
        }
        
        // Debug: Print the raw response
        if let responseString = String(data: data, encoding: .utf8) {
            print("Raw transactions response: \(responseString)")
        }
        
        do {
            // Try to decode the response, but handle missing data gracefully
            let decodedResponse = try JSONDecoder().decode(TransactionResponse.self, from: data)
            return decodedResponse.data.transactions
        } catch {
            print("Failed to decode transactions response: \(error)")
            // If there's no transaction data, return empty array instead of throwing
            return []
        }
    }
    
    // Helper function to get date strings for the last 30 days
    func getLast30DaysDateStrings() -> (from: String, to: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let toDate = Date()
        let fromDate = Calendar.current.date(byAdding: .day, value: -30, to: toDate)!
        
        return (dateFormatter.string(from: fromDate), dateFormatter.string(from: toDate))
    }
    
    // MARK: - New Transfer Functions
    
    /// Get a list of beneficiaries that can receive payments
    func getBeneficiaries(apiKey: String? = nil, clientId: String? = nil, clientSecret: String? = nil) async throws -> [BeneficiaryResponse.Beneficiary] {
        let token = try await getAccessToken(apiKey: apiKey, clientId: clientId, clientSecret: clientSecret)
        let useApiKey = apiKey ?? currentApiKey
        let useBaseURL = currentBaseURL
        var request = URLRequest(url: URL(string: "\(useBaseURL)/za/pb/v1/accounts/beneficiaries")!)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(useApiKey, forHTTPHeaderField: "x-api-key")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "InvestecAPI", code: (response as? HTTPURLResponse)?.statusCode ?? 500,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to fetch beneficiaries: \(errorString)"])
        }
        
        do {
            let beneficiaryResponse = try JSONDecoder().decode(BeneficiaryResponse.self, from: data)
            return beneficiaryResponse.data
        } catch {
            print("Failed to decode beneficiaries, returning empty array. Error: \(error)")
            return []
        }
    }
    
    /// Transfer money between your own Investec accounts
    func transferBetweenAccounts(
        apiKey: String,
        clientId: String,
        clientSecret: String,
        sourceAccountId: String,
        destinationAccountId: String,
        amount: Double,
        myReference: String,
        theirReference: String
    ) async throws -> TransferResponse.TransferResult {
        let token = try await getAccessToken(apiKey: apiKey, clientId: clientId, clientSecret: clientSecret)
        
        let urlString = "\(baseURL)/za/pb/v1/accounts/\(sourceAccountId)/transfermultiple"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "InvestecAPI", code: 400,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        // Create transfer request
        let transferRequest = TransferRequest(
            transferList: [
                TransferRequest.Transfer(
                    beneficiaryAccountId: destinationAccountId,
                    amount: String(format: "%.2f", amount),
                    myReference: myReference,
                    theirReference: theirReference
                )
            ]
        )
        
        // Encode to JSON
        let jsonData = try JSONEncoder().encode(transferRequest)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        // Set longer timeout for transfers (60 seconds instead of default 30)
        request.timeoutInterval = 60
        
        // Create custom URLSession with longer timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 90
        let session = URLSession(configuration: config)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "InvestecAPI", code: 0,
                             userInfo: [NSLocalizedDescriptionKey: "No HTTP response received"])
            }
            
            // Handle different response codes more gracefully
            switch httpResponse.statusCode {
            case 200:
                // Success - try to parse response, but don't fail if parsing fails
                do {
                    let transferResponse = try JSONDecoder().decode(TransferResponse.self, from: data)
                    
                    // Try different ways to get the result
                    let result = transferResponse.data?.transferResponses?.first ??
                                transferResponse.data?.TransferResponses?.first ??
                                transferResponse.data?.transferResponse?.TransferResponses?.first
                    
                    if let result = result {
                        return TransferResponse.TransferResult(
                            status: result.finalStatus,
                            description: result.finalDescription,
                            transferId: result.transferId
                        )
                    } else {
                        // If we can't parse the response, but got 200, assume success
                        return TransferResponse.TransferResult(
                            status: "Success",
                            description: "Transfer completed successfully",
                            transferId: nil
                        )
                    }
                } catch {
                    // If parsing fails but we got 200 status, treat as success
                    print("Failed to parse transfer response, but got 200 status: \(error)")
                    return TransferResponse.TransferResult(
                        status: "Success",
                        description: "Transfer completed successfully",
                        transferId: nil
                    )
                }
                
            case 202:
                // Accepted - transfer is being processed
                return TransferResponse.TransferResult(
                    status: "Accepted",
                    description: "Transfer has been accepted and is being processed. It may take a few minutes to complete.",
                    transferId: nil
                )
                
            case 408, 504:
                // Timeout - but transfer might still succeed
                throw NSError(domain: "InvestecAPI", code: httpResponse.statusCode,
                             userInfo: [NSLocalizedDescriptionKey: "Transfer request timed out, but may still be processing. Please check your account for confirmation."])
                
            default:
                let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("Transfer error response: \(errorString)")
                throw NSError(domain: "InvestecAPI", code: httpResponse.statusCode,
                             userInfo: [NSLocalizedDescriptionKey: "Transfer failed: \(errorString)"])
            }
            
        } catch let error as NSError {
            // Handle specific timeout errors
            if error.code == NSURLErrorTimedOut {
                throw NSError(domain: "InvestecAPI", code: 408,
                             userInfo: [NSLocalizedDescriptionKey: "Transfer request timed out, but may still be processing. Please check your account to confirm the transfer status."])
            }
            throw error
        }
    }
    
    /// Pay a saved beneficiary
    func payBeneficiary(
        apiKey: String,
        clientId: String,
        clientSecret: String,
        sourceAccountId: String,
        beneficiaryId: String,
        amount: Double,
        myReference: String,
        theirReference: String
    ) async throws -> TransferResponse.TransferResult {
        let token = try await getAccessToken(apiKey: apiKey, clientId: clientId, clientSecret: clientSecret)
        
        let urlString = "\(baseURL)/za/pb/v1/accounts/\(sourceAccountId)/paymultiple"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "InvestecAPI", code: 400,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        // Create payment request - note the structure is different from transfer
        let paymentRequest: [String: Any] = [
            "paymentList": [
                [
                    "beneficiaryId": beneficiaryId,
                    "amount": String(format: "%.2f", amount),
                    "myReference": myReference,
                    "theirReference": theirReference
                ]
            ]
        ]
        
        // Encode to JSON
        let jsonData = try JSONSerialization.data(withJSONObject: paymentRequest)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Payment error response: \(errorString)")
            throw NSError(domain: "InvestecAPI", code: (response as? HTTPURLResponse)?.statusCode ?? 500,
                         userInfo: [NSLocalizedDescriptionKey: "Payment failed: \(errorString)"])
        }
        
        // Parse response
        let transferResponse = try JSONDecoder().decode(TransferResponse.self, from: data)
        guard let firstResult = transferResponse.data?.transferResponses?.first ?? transferResponse.data?.transferResponse?.TransferResponses?.first else {
            throw NSError(domain: "InvestecAPI", code: 0,
                         userInfo: [NSLocalizedDescriptionKey: "No payment response received"])
        }
        
        return firstResult
    }
}
