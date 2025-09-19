import Foundation
import Appwrite
import AppwriteModels
import Combine
import JSONCodable

class AppwriteService: ObservableObject {
    static let shared = AppwriteService()
    
    // IMPORTANT: Replace these with your actual Appwrite credentials.
    private let client = Client()
        .setEndpoint("https://nyc.cloud.appwrite.io/v1") // Your Appwrite API Endpoint
        .setProject("68a4d2bf000f0e3d163c") // Your Project ID
    
    var account: Account
    var databases: Databases
    
    @Published var currentUser: AppwriteModels.User<[String: JSONCodable.AnyCodable]>?
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var isGuestMode: Bool = false

    // Appwrite Database and Collection IDs
    let databaseId = "68a4d6440031e3018a98"
    let goalsCollectionId = "68a4d64e0006f5fc82e6"
    let credentialsCollectionId = "68a4db1e003c111ed316"
    let transactionsCollectionId = "68a4d64e0006f5fc82e6"
    
    private let guestEmail = "guest@example.com"
    private let guestPassword = "SecureGuestPassword123!" // Updated to match Appwrite account
    
    // Guest mode sandbox data
    @Published var sandboxGoals: [GoalItem] = []
    @Published var sandboxCredentials: [BankCredential] = []

    private init() {
        self.account = Account(self.client)
        self.databases = Databases(self.client)
        self.initializeSandboxData()
        self.checkAuthenticationStatus()
    }
    
    private func initializeSandboxData() {
        // Initialize sandbox goals with demo data
        sandboxGoals = [
            GoalItem(
                id: "sandbox_goal_1",
                name: "Emergency Fund",
                target: 10000.0,
                saved: 3500.0,
                isTracked: true,
                linkedAccountId: "sandbox_account_1"
            ),
            GoalItem(
                id: "sandbox_goal_2",
                name: "Vacation Fund",
                target: 5000.0,
                saved: 1200.0,
                isTracked: true,
                linkedAccountId: "sandbox_account_2"
            ),
            GoalItem(
                id: "sandbox_goal_3",
                name: "New Car",
                target: 25000.0,
                saved: 8750.0,
                isTracked: true,
                linkedAccountId: "sandbox_account_1"
            )
        ]
        
        // Initialize sandbox bank credentials
        sandboxCredentials = [
            BankCredential(
                id: "sandbox_cred_1",
                clientId: "demo_client_123",
                clientSecret: "demo_secret_456",
                apiKey: "demo_api_key_789",
                userId: "guest_user"
            )
        ]
    }

    private func checkAuthenticationStatus() {
        Task {
            do {
                let user = try await account.get()
                await MainActor.run {
                    self.currentUser = user
                    self.isAuthenticated = true
                    self.isGuestMode = (user.email == self.guestEmail)
                    print("User is authenticated: \(user.name ?? "Unknown")")
                }
            } catch {
                print("User is not authenticated: \(error.localizedDescription)")
                await MainActor.run {
                    self.isAuthenticated = false
                    self.isGuestMode = false
                }
            }
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Auth Methods
    func signUp(email: String, password: String) async throws {
        if isGuestMode {
            throw NSError(domain: "AppwriteService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Guest mode does not support sign up."])
        }
        _ = try await account.create(userId: "unique()", email: email, password: password)
        _ = try await account.createEmailPasswordSession(email: email, password: password)
        let user = try await account.get()
        await MainActor.run {
            self.currentUser = user
            self.isAuthenticated = true
        }
    }
    
    func signIn(email: String, password: String) async throws {
        if isGuestMode {
            throw NSError(domain: "AppwriteService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Guest mode does not support sign in."])
        }
        _ = try await account.createEmailPasswordSession(email: email, password: password)
        let user = try await account.get()
        await MainActor.run {
            self.currentUser = user
            self.isAuthenticated = true
        }
    }
    
    func signInAsGuest() async throws {
        print("Attempting to sign in as guest with email: \(guestEmail)")
        
        // Clear any existing session first to prevent conflicts
        try? await account.deleteSession(sessionId: "current")
        
        do {
            // Sign in with guest credentials
            let session = try await account.createEmailPasswordSession(
                email: guestEmail, 
                password: guestPassword
            )
            
            print("Guest session created successfully: \(session.userId)")
            
            // Get current user info
            let user = try await account.get()
            
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                self.isGuestMode = true
                self.isLoading = false
                print("Guest user authenticated successfully: \(user.email)")
            }
            
        } catch {
            print("Failed to sign in as guest: \(error)")
            throw error
        }
    }
    
    func signOut() async throws {
        if isGuestMode {
            await MainActor.run {
                self.isGuestMode = false
                self.isAuthenticated = false
                self.currentUser = nil
                self.sandboxGoals = [] // Clear sandbox data
            }
        }
        _ = try? await account.deleteSession(sessionId: "current")
        await MainActor.run {
            self.isAuthenticated = false
            self.currentUser = nil
            self.sandboxGoals = [] // Clear sandbox data
        }
    }
    
    // MARK: - Guest Mode
    func setGuestMode(_ enabled: Bool) {
        DispatchQueue.main.async {
            self.isGuestMode = enabled
            if enabled {
                self.isAuthenticated = false
                self.currentUser = nil
                self.isLoading = false
            } else {
                // When disabling guest mode, also check auth status
                self.checkAuthenticationStatus()
            }
        }
    }
    
    // MARK: - Goals Management
    func fetchGoals(for accountId: String? = nil) async throws -> [GoalItem] {
        if isGuestMode {
            // For guest mode, we will now fetch goals from the database
            // associated with the anonymous user.
            guard let userId = currentUser?.id else {
                // Fallback to in-memory sandbox data if no user
                return sandboxGoals
            }
            
            do {
                var queries = [Query.equal("user_id", value: userId), Query.orderDesc("$createdAt")]
                
                // If an account ID is provided, add a filter for it
                if let accountId = accountId {
                    queries.append(Query.equal("linkedAccountId", value: accountId))
                }
                
                let list = try await databases.listDocuments(
                    databaseId: databaseId,
                    collectionId: goalsCollectionId,
                    queries: queries
                ) as DocumentList<[String: JSONCodable.AnyCodable]>
                
                let items: [GoalItem] = list.documents.compactMap { doc in
                    let data = doc.data
                    let name = (data["name"]?.value as? String) ?? "Unnamed Goal"
                    let target = (data["target_amount"]?.value as? Double) ?? ((data["target_amount"]?.value as? NSNumber)?.doubleValue ?? 0)
                    let saved = (data["saved_amount"]?.value as? Double) ?? ((data["saved_amount"]?.value as? NSNumber)?.doubleValue ?? 0)
                    let isTracked = (data["is_tracked"]?.value as? Bool) ?? true
                    let linkedAccountId = data["linkedAccountId"]?.value as? String
                    
                    return GoalItem(id: doc.id, name: name, target: target, saved: saved, isTracked: isTracked, linkedAccountId: linkedAccountId)
                }
                
                return items
            } catch {
                // If there's an error (like the "userld" attribute issue), fall back to sandbox data
                print("Failed to fetch goals from database for guest user, using sandbox data: \(error.localizedDescription)")
                return sandboxGoals
            }
        }
        
        guard let userId = currentUser?.id else {
            throw NSError(domain: "AppwriteService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let list = try await databases.listDocuments(
            databaseId: databaseId,
            collectionId: goalsCollectionId,
            queries: [Query.equal("user_id", value: userId), Query.orderDesc("$createdAt")]
        ) as DocumentList<[String: JSONCodable.AnyCodable]>
        
        let items: [GoalItem] = list.documents.compactMap { doc in
            let data = doc.data
            let name = (data["name"]?.value as? String) ?? "Unnamed Goal"
            let target = (data["target_amount"]?.value as? Double) ?? ((data["target_amount"]?.value as? NSNumber)?.doubleValue ?? 0)
            let saved = (data["saved_amount"]?.value as? Double) ?? ((data["saved_amount"]?.value as? NSNumber)?.doubleValue ?? 0)
            let isTracked = (data["is_tracked"]?.value as? Bool) ?? true
            let linkedAccountId = data["linkedAccountId"]?.value as? String
            
            return GoalItem(id: doc.id, name: name, target: target, saved: saved, isTracked: isTracked, linkedAccountId: linkedAccountId)
        }
        
        return items
    }
    
    func createGoal(name: String, targetAmount: Double, isTracked: Bool, linkedAccountId: String?) async throws -> String {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "AppwriteService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let data: [String: Any] = [
            "name": name,
            "target_amount": targetAmount,
            "saved_amount": 0.0,
            "is_tracked": isTracked,
            "linkedAccountId": linkedAccountId as Any,
            "user_id": userId
        ]
        
        let document = try await databases.createDocument(
            databaseId: databaseId,
            collectionId: goalsCollectionId,
            documentId: "unique()",
            data: data,
            permissions: [
                Permission.read(Role.user(userId)),
                Permission.update(Role.user(userId)),
                Permission.delete(Role.user(userId))
            ]
        ) as Document<[String: JSONCodable.AnyCodable]>
        
        return document.id
    }
    
    func updateGoal(goalId: String, name: String? = nil, targetAmount: Double? = nil, savedAmount: Double? = nil, isTracked: Bool? = nil, linkedAccountId: String? = nil) async throws {
        if isGuestMode {
            // Update goal in sandbox data
            await MainActor.run {
                if let index = self.sandboxGoals.firstIndex(where: { $0.id == goalId }) {
                    var updatedGoal = self.sandboxGoals[index]
                    if let name = name { updatedGoal.name = name }
                    if let targetAmount = targetAmount { updatedGoal.target = targetAmount }
                    if let savedAmount = savedAmount { updatedGoal.saved = savedAmount }
                    if let isTracked = isTracked { updatedGoal.isTracked = isTracked }
                    if let linkedAccountId = linkedAccountId { updatedGoal.linkedAccountId = linkedAccountId }
                    self.sandboxGoals[index] = updatedGoal
                }
            }
            return
        }
        
        guard currentUser?.id != nil else {
            throw NSError(domain: "AppwriteService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        var data: [String: Any] = [:]
        if let name = name { data["name"] = name }
        if let targetAmount = targetAmount { data["target_amount"] = targetAmount }
        if let savedAmount = savedAmount { data["saved_amount"] = savedAmount }
        if let isTracked = isTracked { data["is_tracked"] = isTracked }
        if let linkedAccountId = linkedAccountId { data["linkedAccountId"] = linkedAccountId }
        
        _ = try await databases.updateDocument(
            databaseId: databaseId,
            collectionId: goalsCollectionId,
            documentId: goalId,
            data: data
        )
    }
    
    func deleteGoal(goalId: String) async throws {
        if isGuestMode {
            // Delete goal from sandbox data
            await MainActor.run {
                self.sandboxGoals.removeAll { $0.id == goalId }
            }
            return
        }
        
        guard currentUser?.id != nil else {
            throw NSError(domain: "AppwriteService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        _ = try await databases.deleteDocument(
            databaseId: databaseId,
            collectionId: goalsCollectionId,
            documentId: goalId
        )
    }
    
    // MARK: - Credentials Management
    func fetchCredentials() async throws -> [BankCredential] {
        if isGuestMode {
            // Return sandbox credentials
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 second delay
            return sandboxCredentials
        }
        
        guard currentUser?.id != nil else {
            throw NSError(domain: "AppwriteService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let list = try await databases.listDocuments(
            databaseId: databaseId,
            collectionId: credentialsCollectionId,
            queries: [Query.orderDesc("$createdAt")]
        ) as DocumentList<[String: JSONCodable.AnyCodable]>
        
        let credentials: [BankCredential] = list.documents.compactMap { doc in
            let data = doc.data
            let clientId = data["clientId"]?.value as? String ?? ""
            let clientSecret = data["clientSecret"]?.value as? String ?? ""
            let apiKey = data["apiKey"]?.value as? String ?? ""
            let userId = data["userId"]?.value as? String ?? ""
            
            return BankCredential(id: doc.id, clientId: clientId, clientSecret: clientSecret, apiKey: apiKey, userId: userId)
        }
        
        return credentials
    }
    
    func saveCredentials(clientId: String, clientSecret: String, apiKey: String) async throws -> String {
        if isGuestMode {
            // Save credentials in sandbox data
            let newCredential = BankCredential(
                id: "sandbox_cred_\(UUID().uuidString)",
                clientId: clientId,
                clientSecret: clientSecret,
                apiKey: apiKey,
                userId: "guest_user"
            )
            await MainActor.run {
                self.sandboxCredentials.append(newCredential)
            }
            return newCredential.id
        }
        
        guard let userId = currentUser?.id else {
            throw NSError(domain: "AppwriteService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let data: [String: Any] = [
            "clientId": clientId,
            "clientSecret": clientSecret,
            "apiKey": apiKey,
            "user_id": userId
        ]
        
        let document = try await databases.createDocument(
            databaseId: databaseId,
            collectionId: credentialsCollectionId,
            documentId: "unique()",
            data: data
        ) as Document<[String: JSONCodable.AnyCodable]>
        
        return document.id
    }
    
    // Get the current user ID (real user or guest)
    func getCurrentUserId() -> String {
        if let user = currentUser, user.email == guestEmail {
            return "guest_user_singleton"
        }
        return currentUser?.id ?? ""
    }
    
    // Helper function to check if current user is guest
    func isCurrentUserGuest() -> Bool {
        return currentUser?.email == guestEmail
    }
}
