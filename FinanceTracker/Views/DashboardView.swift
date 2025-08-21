import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appwriteService: AppwriteService
    
    var body: some View {
        NavigationView {
            // Use a ZStack to layer the background and content
            ZStack {
                // Background Gradient
                LinearGradient(
                    colors: [.blue.opacity(0.05), .purple.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Main content VStack - NO ScrollView
                VStack(spacing: 0) {
                    // Header Section
                    headerSection
                        .padding(.bottom, 12) // Reduced spacing
                    
                    // Main Content Sections
                    VStack(spacing: 16) { // Reduced spacing between sections
                        // Goals Section
                        sectionCard(
                            title: "Goals",
                            subtitle: "Track your savings progress",
                            icon: "target"
                        ) {
                            goalsCards
                        }
                        
                        // Banking Section
                        sectionCard(
                            title: "Banking",
                            subtitle: "Manage your finances",
                            icon: "banknote"
                        ) {
                            bankingCards
                        }
                        
                        // Settings Section
                        sectionCard(
                            title: "Settings",
                            subtitle: "Configure your account",
                            icon: "gearshape"
                        ) {
                            settingsCards
                        }
                    }
                    .padding(.horizontal, 16) // Reduced horizontal padding
                    
                    Spacer() // Pushes content up
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack) // Use stack style for better layout control
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) { // Reduced spacing
            // App title
            HStack {
                Text("Finance Tracker")
                    .font(.system(size: 26, weight: .bold, design: .rounded)) // Reduced font size
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16) // Reduced top padding
            
            // Welcome message
            HStack {
                VStack(alignment: .leading, spacing: 2) { // Reduced spacing
                    Text("Welcome back,")
                        .font(.system(size: 15)) // Reduced font size
                        .foregroundColor(.secondary)
                    
                    Text(appwriteService.currentUser?.name ?? "User")
                        .font(.system(size: 22, weight: .semibold)) // Reduced font size
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // User avatar
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44) // Reduced size
                        .shadow(color: .blue.opacity(0.2), radius: 5, x: 0, y: 2)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 18)) // Reduced size
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    private func sectionCard<Content: View>(
        title: String,
        subtitle: String,
        icon: String,
        @ViewBuilder cards: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) { // Reduced spacing
            // Section header
            HStack(spacing: 10) { // Reduced spacing
                ZStack {
                    Circle()
                        .fill(.blue.opacity(0.1))
                        .frame(width: 36, height: 36) // Reduced size
                    
                    Image(systemName: icon)
                        .font(.system(size: 16)) // Reduced size
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 1) { // Reduced spacing
                    Text(title)
                        .font(.system(size: 18, weight: .bold)) // Reduced font size
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 13)) // Reduced font size
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Cards grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) { // Reduced spacing
                cards()
            }
        }
        .padding(16) // Reduced padding
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16)) // Reduced corner radius
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private var goalsCards: some View {
        Group {
            NavigationLink(destination: GoalsListView()) {
                StunningDashboardCard(
                    title: "View Goals",
                    subtitle: "Track progress",
                    icon: "target",
                    color: .indigo
                )
            }
            
            NavigationLink(destination: StunningGoalCreationView()) {
                StunningDashboardCard(
                    title: "Create Goal",
                    subtitle: "Set new target",
                    icon: "plus.circle.fill",
                    color: .blue
                )
            }
        }
    }
    
    private var bankingCards: some View {
        Group {
            NavigationLink(destination: StunningTransferView()) {
                StunningDashboardCard(
                    title: "Transfer Money",
                    subtitle: "Link to goals",
                    icon: "arrow.left.arrow.right.circle.fill",
                    color: .orange
                )
            }
            
            NavigationLink(destination: TransactionsView()) {
                StunningDashboardCard(
                    title: "Transactions",
                    subtitle: "Recent activity",
                    icon: "creditcard.fill",
                    color: .teal
                )
            }
        }
    }
    
    private var settingsCards: some View {
        Group {
            NavigationLink(destination: CredentialsView()) {
                StunningDashboardCard(
                    title: "Bank Connection",
                    subtitle: "Investec setup",
                    icon: "building.2.fill",
                    color: .green
                )
            }
            
            Button {
                Task {
                    do {
                        try await appwriteService.signOut()
                    } catch {
                        print("Error signing out: \(error.localizedDescription)")
                    }
                }
            } label: {
                StunningDashboardCard(
                    title: "Sign Out",
                    subtitle: "Exit account",
                    icon: "rectangle.portrait.and.arrow.right",
                    color: .red
                )
            }
        }
    }
}

struct StunningDashboardCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) { // Reduced spacing
            // Icon with background
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44) // Reduced size
                
                Image(systemName: icon)
                    .font(.system(size: 20)) // Reduced size
                    .foregroundColor(color)
            }
            
            // Text content
            VStack(spacing: 2) { // Reduced spacing
                Text(title)
                    .font(.system(size: 15, weight: .semibold)) // Reduced font size
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(subtitle)
                    .font(.system(size: 11)) // Reduced font size
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12) // Reduced padding
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppwriteService.shared)
}
