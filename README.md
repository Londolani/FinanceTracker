# FinanceTracker

FinanceTracker is an iOS application designed to help users manage their personal finances, track financial goals, and monitor transactions. It provides a comprehensive overview of your financial health, allowing you to set and achieve savings goals and securely manage your bank credentials.

True power comes from allowing you to save in your car/loan account and assign transactions to linked savings goals, making it easier to save money in those accounts and be discplined in those transactions since accounts have instant access. Another feature is monthly replay, which just checks your transactions for the month and creates a Spotify Wrapped-like feature of the insights from the transactions, which will be later linked to Gemini flash model for better insights 

## Features

- **User Authentication:** Secure sign-up and sign-in, including a guest mode for exploration.
- **Goal Management:** Create, track, update, and delete financial goals (e.g., emergency fund, vacation, new car) and link them to accounts. 
- **Bank Credential Management:** Securely store and manage bank API credentials.
- **Transaction Tracking:** (Implied from `TransactionsView.swift` and `Transaction.swift`)
- **Dashboard Overview:** (Implied from `DashboardView.swift`)
- **Monthly Replay:** (Implied from `MonthlyReplayView.swift`)

## Technologies Used

- **SwiftUI:** For building the user interface.
- **Appwrite:** As the backend-as-a-service for authentication, database, and more.
- **Investec API:** (Implied from `InvestecService.swift`) For potential bank integrations.

## Getting Started

To get a local copy up and running, follow these steps.

### Prerequisites

- Xcode (latest version recommended)
- Swift (latest version recommended)
- An Appwrite instance (local or cloud)

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-username/FinanceTracker.git
    cd FinanceTracker
    ```

2.  **Open in Xcode:**
    Open the `FinanceTracker.xcodeproj` file in Xcode.

3.  **Install Dependencies:**
    Ensure all Swift Package Manager dependencies are resolved. Xcode should do this automatically.

4.  **Appwrite Configuration:**
    This project uses Appwrite for its backend. You need to set up your Appwrite project and configure the application with your credentials.

    a.  **Set up your Appwrite Project:**
        If you haven't already, create a project in your Appwrite console. Note down your Project ID and API Endpoint.

    b.  **Create Databases and Collections:**
        Create the following database and collections in your Appwrite project:
        -   **Database:** (e.g., `FinanceTrackerDB`)
        -   **Collections:**
            -   `goals`
            -   `credentials`
            -   `transactions`

    c.  **Update `AppwriteConfig.swift`:**
        The `AppwriteConfig.swift` file contains placeholders for your Appwrite credentials. **This file is intentionally excluded from Git via `.gitignore` for security reasons.** You will need to create this file manually or ensure it exists with your actual Appwrite details.

        Create a file at `FinanceTracker/FinanceTracker/Services/AppwriteConfig.swift` with the following structure, replacing the placeholder values with your actual Appwrite project details:

        ```swift
        import Foundation

        struct AppwriteConfig {
            static let endpoint = "https://nyc.cloud.appwrite.io/v1" // Your Appwrite API Endpoint
            static let projectID = "YOUR_APPWRITE_PROJECT_ID" // Your Project ID
            
            // Appwrite Database and Collection IDs
            static let databaseId = "YOUR_APPWRITE_DATABASE_ID"
            static let goalsCollectionId = "YOUR_GOALS_COLLECTION_ID"
            static let credentialsCollectionId = "YOUR_CREDENTIALS_COLLECTION_ID"
            static let transactionsCollectionId = "YOUR_TRANSACTIONS_COLLECTION_ID"
            
            static let guestEmail = "guest@example.com"
            static let guestPassword = "SecureGuestPassword123!"
        }
        ```
        **Note:** The `guestEmail` and `guestPassword` are used for the guest mode functionality. You might need to create a user with these credentials in your Appwrite console if you want to test the guest mode with a persistent backend.

5.  **Run the Application:**
    Select a simulator or a connected iOS device in Xcode and run the application.

## Project Structure

```
FinanceTracker/
	FinanceTrackerApp.swift
	GenerativeAI-Info.plist
	GoogleService-Info.plist
	Assets.xcassets/
	Models/
		BankCredential.swift
		GoalItem.swift
		Transaction.swift
	Services/
		AppwriteService.swift
		AppwriteConfig.swift
		InvestecService.swift
	Utilities/
		Extensions.swift
	Views/
		AuthView.swift
		ConfettiView.swift
		CredentialsView.swift
		DashboardView.swift
		GoalCreationView.swift
		GoalDetailView.swift
		GoalsListView.swift
		MonthlyReplayView.swift
		StunningGoalCreationView.swift
		StunningTransferView.swift
		TransactionsView.swift
		TransferView.swift
```

## Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

## License

Distributed under the MIT License. See `LICENSE` for more information. (Note: A `LICENSE` file is not included in the provided structure, you may want to add one.)

## Contact

Your Name/Project Maintainer - [londolani0700@gmail.com](mailto:londolani0700@gmail.com)
Project Link: [https://github.com/londolani/FinanceTracker](https://github.com/londolani/FinanceTracker)
