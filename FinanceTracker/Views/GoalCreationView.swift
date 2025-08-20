import SwiftUI
import Appwrite

struct GoalCreationView: View {
    @State private var goalName = ""
    @State private var targetAmount = 0.0
    @State private var showSuccess = false
    @State private var isLoading = false
    @EnvironmentObject var appwriteService: AppwriteService
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [.blue.opacity(0.1), .cyan.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            Form {
                Section(header: Text("New Savings Goal").font(.headline)) {
                    TextField("Goal Name (e.g., 'Car Loan')", text: $goalName)
                    
                    HStack {
                        Text("R")
                        TextField("Target Amount", value: $targetAmount, format: .number)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section {
                    Button("Create Goal") {
                        createGoal()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(goalName.isEmpty || targetAmount <= 0 || isLoading)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Create Goal")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Goal Created!", isPresented: $showSuccess) {
            Button("OK", role: .cancel) { }
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }
    
    private func createGoal() {
        Task {
            guard let userId = appwriteService.currentUser?.id else { return }
            
            await MainActor.run { isLoading = true }
            
            let newGoal = [
                "name": goalName,
                "target_amount": targetAmount,
                "saved_amount": 0.0,
                "is_tracked": true
            ] as [String : Any]
            
            let permissions = [
                Permission.read(Role.user(userId)),
                Permission.write(Role.user(userId))
            ]
            
            do {
                _ = try await appwriteService.databases.createDocument(
                    databaseId: appwriteService.databaseId,
                    collectionId: appwriteService.goalsCollectionId,
                    documentId: "unique()",
                    data: newGoal,
                    permissions: permissions
                )
                await MainActor.run {
                    showSuccess = true
                    goalName = ""
                    targetAmount = 0.0
                    isLoading = false
                }
            } catch {
                print("Error creating goal: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}

#Preview {
    NavigationView {
        GoalCreationView()
            .environmentObject(AppwriteService.shared)
    }
}
