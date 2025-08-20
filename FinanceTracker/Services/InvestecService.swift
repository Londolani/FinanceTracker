import Foundation
import Combine

class InvestecService: ObservableObject {
    static let shared = InvestecService()
    
    private var accessToken: String?
    private var expiresAt: Date?
    
    // Investec API endpoints
    private let baseURL = "https://openapi.investec.com"
    private let tokenURL = "https://openapi.investec.com/identity/v2/oauth2/token"
    
    // MARK: - Models
    
    struct Transaction: Identifiable, Codable {
        let id: String
        let accountId: String
        let type: String
        let description: String
        let amount: Double
        let date: String
        var runningBalance: Double?
        
        enum CodingKeys: String, CodingKey {
            case accountId
            case type
            case description
            case amount
            case runningBalance
            case transactionDate = "transactionDate"
            case transactionId = "transactionId"
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            accountId = try container.decode(String.self, forKey: .accountId)
            type = try container.decode(String.self, forKey: .type)
            description = try container.decode(String.self, forKey: .description)
            amount = try container.decode(Double.self, forKey: .amount)
            date = try container.decodeIfPresent(String.self, forKey: .transactionDate) ?? ""
            runningBalance = try container.decodeIfPresent(Double.self, forKey: .runningBalance)
            
            // Use transactionId if available, otherwise create a UUID
            if let transactionId = try container.decodeIfPresent(String.self, forKey: .transactionId) {
                id = transactionId
            } else {
                id = UUID().uuidString
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(accountId, forKey: .accountId)
            try container.encode(type, forKey: .type)
            try container.encode(description, forKey: .description)
            try container.encode(amount, forKey: .amount)
            try container.encode(date, forKey: .transactionDate)
            try container.encodeIfPresent(runningBalance, forKey: .runningBalance)
            try container.encode(id, forKey: .transactionId)
        }
    }
    
    struct TransactionResponse: Codable {
        let data: TransactionData
        
        struct TransactionData: Codable {
            let transactions: [Transaction]
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
    
    func getAccessToken(apiKey: String, clientId: String, clientSecret: String) async throws -> String {
        // Check if we have a valid token
        if let token = accessToken, let expiryDate = expiresAt, expiryDate > Date() {
            return token
        }
        
        // Create base64 encoded credentials
        let credentials = "\(clientId):\(clientSecret)".data(using: .utf8)!.base64EncodedString()
        
        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.addValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
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
        
        // Save token with expiry
        self.accessToken = token
        self.expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn - 60)) // Buffer of 1 minute
        
        return token
    }
    
    func getAccounts(apiKey: String, clientId: String, clientSecret: String) async throws -> [AccountResponse.Account] {
        let token = try await getAccessToken(apiKey: apiKey, clientId: clientId, clientSecret: clientSecret)
        
        var request = URLRequest(url: URL(string: "\(baseURL)/za/pb/v1/accounts")!)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "InvestecAPI", code: (response as? HTTPURLResponse)?.statusCode ?? 500, 
                         userInfo: [NSLocalizedDescriptionKey: "Failed to fetch accounts: \(errorString)"])
        }
        
        let accountResponse = try JSONDecoder().decode(AccountResponse.self, from: data)
        return accountResponse.data.accounts
    }
    
    func getTransactions(apiKey: String, clientId: String, clientSecret: String, accountId: String, 
                         fromDate: String, toDate: String) async throws -> [Transaction] {
        let token = try await getAccessToken(apiKey: apiKey, clientId: clientId, clientSecret: clientSecret)
        
        let urlString = "\(baseURL)/za/pb/v1/accounts/\(accountId)/transactions?fromDate=\(fromDate)&toDate=\(toDate)"
        
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "InvestecAPI", code: 400, 
                         userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Error response: \(errorString)")
            throw NSError(domain: "InvestecAPI", code: (response as? HTTPURLResponse)?.statusCode ?? 500, 
                         userInfo: [NSLocalizedDescriptionKey: "Failed to fetch transactions: \(errorString)"])
        }
        
        let transactionResponse = try JSONDecoder().decode(TransactionResponse.self, from: data)
        return transactionResponse.data.transactions
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
    func getBeneficiaries(apiKey: String, clientId: String, clientSecret: String) async throws -> [BeneficiaryResponse.Beneficiary] {
        let token = try await getAccessToken(apiKey: apiKey, clientId: clientId, clientSecret: clientSecret)
        
        var request = URLRequest(url: URL(string: "\(baseURL)/za/pb/v1/accounts/beneficiaries")!)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "InvestecAPI", code: (response as? HTTPURLResponse)?.statusCode ?? 500, 
                         userInfo: [NSLocalizedDescriptionKey: "Failed to fetch beneficiaries: \(errorString)"])
        }
        
        let beneficiaryResponse = try JSONDecoder().decode(BeneficiaryResponse.self, from: data)
        return beneficiaryResponse.data
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
