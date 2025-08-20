import SwiftUI
import Appwrite
import JSONCodable

struct GoalsListView: View {
    @EnvironmentObject var appwriteService: AppwriteService
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var goals: [GoalItem] = []

    var body: some View {
        ZStack {
            LinearGradient(colors: [.blue.opacity(0.1), .purple.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 16) {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                if isLoading {
                    ProgressView("Loading your goals...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if goals.isEmpty {
                    ContentUnavailableView(
                        "No Goals Yet",
                        systemImage: "target",
                        description: Text("Create your first savings goal to get started!")
                    )
                } else {
                    List(goals) { goal in
                        GoalCard(goal: goal)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .listStyle(.plain)
                    .background(Color.clear)
                    .refreshable {
                        await loadGoals()
                    }
                }
            }
        }
        .task { await loadGoals() }
        .navigationTitle("Your Goals")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func GoalCard(goal: GoalItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(goal.progress * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(goal.progress >= 1.0 ? .green : .blue)
                    
                    if goal.progress >= 1.0 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
            
            ProgressView(value: goal.progress)
                .tint(goal.progress >= 1.0 ? .green : .blue)
                .scaleEffect(y: 1.5)
            
            HStack {
                Label("Saved: R\(format(goal.saved))", systemImage: "banknote.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                
                Spacer()
                
                Label("Target: R\(format(goal.target))", systemImage: "target")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            if goal.target > goal.saved {
                HStack {
                    Text("Remaining: R\(format(goal.target - goal.saved))")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(goal.progress >= 1.0 ? .green.opacity(0.3) : .blue.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    private func format(_ value: Double) -> String {
        NumberFormatter.currency.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private func loadGoals() async {
        guard appwriteService.currentUser?.id != nil else { return }
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        do {
            let list = try await appwriteService.databases.listDocuments(
                databaseId: appwriteService.databaseId,
                collectionId: appwriteService.goalsCollectionId,
                queries: [Query.orderDesc("$createdAt")]
            ) as DocumentList<[String: JSONCodable.AnyCodable]>
            let items: [GoalItem] = list.documents.compactMap { doc in
                let data = doc.data
                let name = (data["name"]?.value as? String) ?? "Unnamed Goal"
                let target = (data["target_amount"]?.value as? Double) ?? ((data["target_amount"]?.value as? NSNumber)?.doubleValue ?? 0)
                let saved = (data["saved_amount"]?.value as? Double) ?? ((data["saved_amount"]?.value as? NSNumber)?.doubleValue ?? 0)
                let isTracked = (data["is_tracked"]?.value as? Bool) ?? true
                let linkedAccountId = data["linkedAccountId"]?.value as? String // Fixed: use camelCase to match creation
                
                return GoalItem(id: doc.id, name: name, target: target, saved: saved, isTracked: isTracked, linkedAccountId: linkedAccountId)
            }
            await MainActor.run {
                self.goals = items
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load goals: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

struct GoalItem: Identifiable, Hashable, Equatable {
    let id: String
    let name: String
    let target: Double
    let saved: Double
    let isTracked: Bool
    let linkedAccountId: String? // Add the linked account ID field
    
    var progress: Double {
        target > 0 ? min(saved / target, 1.0) : 0
    }
    
    // Hashable and Equatable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: GoalItem, rhs: GoalItem) -> Bool {
        lhs.id == rhs.id
    }
}

#Preview {
    NavigationView {
        GoalsListView()
            .environmentObject(AppwriteService.shared)
    }
}
