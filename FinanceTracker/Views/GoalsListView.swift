import SwiftUI
import Appwrite
import JSONCodable

struct GoalsListView: View {
    @EnvironmentObject var appwriteService: AppwriteService
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var goals: [GoalItem] = []

    var body: some View {
        VStack {
            // Header with back button
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
                
                Spacer()
                
                Text("Your Goals")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                
                Spacer()
                
                Circle()
                    .frame(width: 34, height: 34)
                    .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            // Main content
            ZStack {
                LinearGradient(colors: [.blue.opacity(0.05), .purple.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 12) {
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                            .padding(.horizontal)
                    }
                    
                    if isLoading {
                        VStack {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading your goals...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if goals.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "target")
                                .font(.system(size: 48))
                                .foregroundColor(.blue.opacity(0.6))
                            
                            Text("No Goals Yet")
                                .font(.system(size: 20, weight: .bold))
                            
                            Text("Create your first savings goal to get started!")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(goals) { goal in
                            NavigationLink(destination: GoalDetailView(goal: goal)) {
                                CompactGoalCard(goal: goal)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                        .listStyle(.plain)
                        .background(Color.clear)
                        .refreshable {
                            await loadGoals()
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .task { await loadGoals() }
        .onReceive(appwriteService.$isGuestMode) { isGuest in
            if isGuest {
                // Clear any previously loaded goals when switching to guest mode
                goals = []
                Task {
                    await loadGoals()
                }
            }
        }
        .onReceive(appwriteService.$isAuthenticated) { isAuth in
            if !isAuth {
                // Clear goals when user signs out
                goals = []
            }
        }
    }

    @ViewBuilder
    private func CompactGoalCard(goal: GoalItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(.system(size: 16, weight: .semibold))
                        .fontWeight(.medium)
                    
                    Text("Progress")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(goal.progress * 100))%")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(goal.progress >= 1.0 ? .green : .blue)
                    
                    if goal.progress >= 1.0 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 14))
                    }
                }
            }
            
            ProgressView(value: goal.progress)
                .tint(goal.progress >= 1.0 ? .green : .blue)
                .scaleEffect(y: 1.2)
            
            HStack {
                Label("R\(format(goal.saved))", systemImage: "banknote.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
                
                Spacer()
                
                Label("R\(format(goal.target))", systemImage: "target")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
            }
            
            if goal.target > goal.saved {
                HStack {
                    Text("Remaining: R\(format(goal.target - goal.saved))")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(goal.progress >= 1.0 ? .green.opacity(0.3) : .blue.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func format(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.0fk", value / 1000)
        } else {
            return String(format: "%.0f", value)
        }
    }

    private func loadGoals() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let fetchedGoals = try await appwriteService.fetchGoals()
            await MainActor.run {
                self.goals = fetchedGoals
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                if let appwriteError = error as? AppwriteError, appwriteError.type == "general_argument_invalid" {
                    self.errorMessage = "Failed to load goals: Invalid query. Please check the 'userId' attribute in your Appwrite collection schema. It might be misspelled as 'userld'."
                } else {
                    self.errorMessage = "Failed to load goals: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        GoalsListView()
            .environmentObject(AppwriteService.shared)
    }
}
