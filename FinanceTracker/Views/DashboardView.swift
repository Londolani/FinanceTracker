import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appwriteService: AppwriteService
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(colors: [.blue.opacity(0.05), .purple.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Welcome Header
                        VStack(spacing: 8) {
                            Text("Welcome back!")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text(appwriteService.currentUser?.name ?? "User")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 20)
                        
                        // Goals Section
                        VStack(alignment: .leading) {
                            Text("Goals")
                                .font(.title3)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                
                                NavigationLink(destination: GoalsListView()) {
                                    DashboardCard(
                                        title: "View Goals",
                                        subtitle: "Track your progress",
                                        icon: "target",
                                        color: .indigo
                                    )
                                }
                                
                                NavigationLink(destination: GoalCreationView()) {
                                    DashboardCard(
                                        title: "Create Goal",
                                        subtitle: "Set new target",
                                        icon: "plus.circle.fill",
                                        color: .blue
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Banking Section
                        VStack(alignment: .leading) {
                            Text("Banking")
                                .font(.title3)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                
                                NavigationLink(destination: TransferView()) {
                                    DashboardCard(
                                        title: "Transfer Money",
                                        subtitle: "Link to goals",
                                        icon: "arrow.left.arrow.right.circle.fill",
                                        color: .orange
                                    )
                                }
                                
                                NavigationLink(destination: TransactionsView()) {
                                    DashboardCard(
                                        title: "Transactions",
                                        subtitle: "Recent activity",
                                        icon: "creditcard.fill",
                                        color: .teal
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Settings Section
                        VStack(alignment: .leading) {
                            Text("Settings")
                                .font(.title3)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                
                                NavigationLink(destination: CredentialsView()) {
                                    DashboardCard(
                                        title: "Bank Connection",
                                        subtitle: "Investec integration",
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
                                    DashboardCard(
                                        title: "Sign Out",
                                        subtitle: "Exit your account",
                                        icon: "rectangle.portrait.and.arrow.right",
                                        color: .red
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Finance Tracker")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct DashboardCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(color)
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(color.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppwriteService.shared)
}
