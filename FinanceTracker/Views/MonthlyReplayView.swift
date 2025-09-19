import SwiftUI

struct MonthlyReplayView: View {
    var transactions: [Transaction]
    var month: Int
    var year: Int
    
    @State private var currentSlide = 0
    @State private var showContent = false
    
    private var monthName: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"
        guard let date = Calendar.current.date(from: DateComponents(year: year, month: month)) else {
            return "Unknown"
        }
        return dateFormatter.string(from: date)
    }
    
    // MARK: - Smart Analytics
    
    private var totalIncome: Double {
        transactions.filter { $0.type == "CREDIT" }.reduce(0) { $0 + $1.amount }
    }
    
    private var totalExpense: Double {
        transactions.filter { $0.type == "DEBIT" }.reduce(0) { $0 + $1.amount }
    }
    
    private var netIncome: Double {
        totalIncome - totalExpense
    }
    
    private var savingsRate: Double {
        guard totalIncome > 0 else { return 0 }
        return (netIncome / totalIncome) * 100
    }
    
    private var categories: [String: (amount: Double, count: Int, transactions: [Transaction])] {
        var result = [String: (amount: Double, count: Int, transactions: [Transaction])]()
        let debitTransactions = transactions.filter { $0.type == "DEBIT" }
        
        for transaction in debitTransactions {
            let category = getCategoryFromTransactionType(transaction.transactionType ?? "Other")
            var current = result[category] ?? (amount: 0, count: 0, transactions: [])
            current.amount += transaction.amount
            current.count += 1
            current.transactions.append(transaction)
            result[category] = current
        }
        return result
    }
    
    private func getCategoryFromTransactionType(_ type: String) -> String {
        switch type.lowercased() {
        case "cardpurchases": return "Shopping"
        case "atmwithdrawals": return "Cash Withdrawals"
        case "onlinebankingpayments": return "Transfers & Payments"
        case "payshap": return "Instant Payments"
        case "debitorders": return "Subscriptions & Bills"
        case "feesandinterest": return "Bank Fees"
        default: return "Other"
        }
    }
    
    private var topSpendingCategories: [(category: String, amount: Double, count: Int, percentage: Double)] {
        return categories.map { key, value in
            let percentage = totalExpense > 0 ? (value.amount / totalExpense) * 100 : 0
            return (category: key, amount: value.amount, count: value.count, percentage: percentage)
        }.sorted { $0.amount > $1.amount }
    }
    
    private var biggestExpense: Transaction? {
        transactions.filter { $0.type == "DEBIT" }.max(by: { $0.amount < $1.amount })
    }
    
    private var mostFrequentVendor: (vendor: String, count: Int, amount: Double)? {
        let debitTransactions = transactions.filter { $0.type == "DEBIT" }
        let vendorCounts = debitTransactions.reduce(into: [String: (count: Int, amount: Double)]()) { result, transaction in
            let vendor = transaction.description
            var current = result[vendor] ?? (count: 0, amount: 0)
            current.count += 1
            current.amount += transaction.amount
            result[vendor] = current
        }
        
        return vendorCounts.max(by: { $0.value.count < $1.value.count })
            .map { ($0.key, $0.value.count, $0.value.amount) }
    }
    
    private var spendingPattern: (peak: String, quiet: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let dailySpending = transactions.filter { $0.type == "DEBIT" }
            .reduce(into: [String: Double]()) { result, transaction in
                guard let dateString = transaction.transactionDate else { return }
                result[dateString, default: 0] += transaction.amount
            }
        
        let peak = dailySpending.max(by: { $0.value < $1.value })?.key ?? ""
        let quiet = dailySpending.min(by: { $0.value < $1.value })?.key ?? ""
        
        return (peak: formatDate(peak), quiet: formatDate(quiet))
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "EEEE, MMM d"
        return outputFormatter.string(from: date)
    }
    
    private var averageTransactionSize: Double {
        let debitTransactions = transactions.filter { $0.type == "DEBIT" }
        guard !debitTransactions.isEmpty else { return 0 }
        return debitTransactions.reduce(0) { $0 + $1.amount } / Double(debitTransactions.count)
    }
    
    private var financialHealth: (status: String, color: Color, message: String) {
        if savingsRate > 20 {
            return ("Excellent", .green, "You're building wealth!")
        } else if savingsRate > 10 {
            return ("Good", .blue, "Keep up the good work")
        } else if savingsRate > 0 {
            return ("Fair", .orange, "Room for improvement")
        } else {
            return ("Needs Attention", .red, "Consider reducing expenses")
        }
    }
    
    private var weekdayVsWeekendSpending: (weekday: Double, weekend: Double) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var weekdaySpending: Double = 0
        var weekendSpending: Double = 0
        
        for transaction in transactions.filter({ $0.type == "DEBIT" }) {
            guard let dateString = transaction.transactionDate,
                  let date = dateFormatter.date(from: dateString) else { continue }
            
            let calendar = Calendar.current
            let weekday = calendar.component(.weekday, from: date)
            
            if weekday == 1 || weekday == 7 { // Sunday or Saturday
                weekendSpending += transaction.amount
            } else {
                weekdaySpending += transaction.amount
            }
        }
        
        return (weekday: weekdaySpending, weekend: weekendSpending)
    }
    
    var body: some View {
        TabView(selection: $currentSlide) {
            // Slide 1: Welcome
            WelcomeSlide(monthName: monthName, year: year)
                .tag(0)
            
            // Slide 2: Loading/Processing
            ProcessingSlide()
                .tag(1)
            
            // Slide 3: Income
            IncomeSlide(amount: totalIncome)
                .tag(2)
            
            // Slide 4: Expenses  
            ExpenseSlide(amount: totalExpense)
                .tag(3)
            
            // Slide 5: Net Income
            NetIncomeSlide(amount: netIncome, savingsRate: savingsRate, health: financialHealth)
                .tag(4)
            
            // Slide 6: Top Category
            if let topCategory = topSpendingCategories.first {
                TopCategorySlide(category: topCategory)
                    .tag(5)
            }
            
            // Slide 7: Category Breakdown
            CategoryBreakdownSlide(categories: topSpendingCategories)
                .tag(6)
            
            // Slide 8: Biggest Purchase
            if let biggest = biggestExpense {
                BiggestPurchaseSlide(transaction: biggest)
                    .tag(7)
            }
            
            // Slide 9: Most Frequent Vendor
            if let vendor = mostFrequentVendor {
                FrequentVendorSlide(vendor: vendor)
                    .tag(8)
            }
            
            // Slide 10: Spending Patterns
            SpendingPatternSlide(pattern: spendingPattern, average: averageTransactionSize)
                .tag(9)
            
            // Slide 11: Weekday vs Weekend
            WeekdayWeekendSlide(weekdayVsWeekend: weekdayVsWeekendSpending)
                .tag(10)
            
            // Slide 12: Financial Health Summary
            HealthSummarySlide(health: financialHealth, savingsRate: savingsRate)
                .tag(11)
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .background(Color.black.ignoresSafeArea())
        .ignoresSafeArea()
        .onAppear {
            // Auto-advance through first two slides
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeInOut(duration: 0.8)) {
                    currentSlide = 1
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation(.easeInOut(duration: 0.8)) {
                    currentSlide = 2
                }
            }
        }
    }
}

// MARK: - Individual Slide Views

struct WelcomeSlide: View {
    let monthName: String
    let year: Int
    @State private var animate = false
    
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [.purple, .blue, .black],
                center: .center,
                startRadius: 100,
                endRadius: 500
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Image(systemName: "sparkles")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .scaleEffect(animate ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animate)
                
                Text("Your \(monthName) \(year)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Financial Story")
                    .font(.system(size: 32, weight: .light, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("✨ Get ready for some insights ✨")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 20)
            }
            .onAppear {
                animate = true
            }
        }
    }
}

struct ProcessingSlide: View {
    @State private var progress: Double = 0
    @State private var currentText = "Analyzing your transactions..."
    
    private let loadingTexts = [
        "Analyzing your transactions...",
        "Categorizing your spending...",
        "Finding patterns...",
        "Calculating insights...",
        "Almost ready! ✨"
    ]
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black, .gray.opacity(0.3), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 60))
                    .foregroundColor(.cyan)
                
                Text("Processing")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                ProgressView(value: progress, total: 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: .cyan))
                    .scaleEffect(x: 1, y: 4)
                    .frame(width: 200)
                
                Text(currentText)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .onAppear {
                startProgress()
            }
        }
    }
    
    private func startProgress() {
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { timer in
            withAnimation(.easeInOut(duration: 0.3)) {
                progress += 20
                
                if progress <= 100 {
                    let index = min(Int(progress / 20), loadingTexts.count - 1)
                    currentText = loadingTexts[index]
                }
                
                if progress >= 100 {
                    timer.invalidate()
                }
            }
        }
    }
}

struct IncomeSlide: View {
    let amount: Double
    @State private var showAmount = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.green.opacity(0.3), .mint.opacity(0.5), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 25) {
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.green)
                
                Text("You Earned")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                if showAmount {
                    Text("R\(amount, specifier: "%.2f")")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                }
                
                Text("Total Income This Month")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        showAmount = true
                    }
                }
            }
        }
    }
}

struct ExpenseSlide: View {
    let amount: Double
    @State private var showAmount = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.red.opacity(0.3), .orange.opacity(0.5), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 25) {
                Image(systemName: "arrow.down.left.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.red)
                
                Text("You Spent")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                if showAmount {
                    Text("R\(amount, specifier: "%.2f")")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                        .transition(.scale.combined(with: .opacity))
                }
                
                Text("Total Expenses This Month")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        showAmount = true
                    }
                }
            }
        }
    }
}

struct NetIncomeSlide: View {
    let amount: Double
    let savingsRate: Double
    let health: (status: String, color: Color, message: String)
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [health.color.opacity(0.3), .blue.opacity(0.5), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: amount >= 0 ? "plus.circle.fill" : "minus.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(amount >= 0 ? .green : .red)
                
                Text("Net Result")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                if showContent {
                    VStack(spacing: 15) {
                        Text("\(amount >= 0 ? "+" : "")R\(amount, specifier: "%.2f")")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(amount >= 0 ? .green : .red)
                        
                        Text("Savings Rate: \(savingsRate, specifier: "%.1f")%")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        
                        HStack {
                            Circle()
                                .fill(health.color)
                                .frame(width: 12, height: 12)
                            Text(health.status)
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(health.color)
                        }
                        
                        Text(health.message)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        showContent = true
                    }
                }
            }
        }
    }
}

struct TopCategorySlide: View {
    let category: (category: String, amount: Double, count: Int, percentage: Double)
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.purple.opacity(0.4), .pink.opacity(0.6), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 25) {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.purple)
                
                Text("Your Top Category")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                if showContent {
                    VStack(spacing: 15) {
                        Text(category.category)
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(.purple)
                            .multilineTextAlignment(.center)
                        
                        Text("R\(category.amount, specifier: "%.2f")")
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("\(category.count) transactions • \(category.percentage, specifier: "%.1f")% of spending")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        showContent = true
                    }
                }
            }
        }
    }
}

struct CategoryBreakdownSlide: View {
    let categories: [(category: String, amount: Double, count: Int, percentage: Double)]
    @State private var showBars = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.indigo.opacity(0.4), .blue.opacity(0.6), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 25) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Spending Breakdown")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                if showBars {
                    VStack(spacing: 12) {
                        ForEach(Array(categories.prefix(5).enumerated()), id: \.offset) { index, category in
                            HStack {
                                Text(category.category)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(width: 120, alignment: .leading)
                                
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(.white.opacity(0.2))
                                        .frame(height: 8)
                                        .cornerRadius(4)
                                    
                                    Rectangle()
                                        .fill(Color.blue)
                                        .frame(width: CGFloat(category.percentage) * 1.5, height: 8)
                                        .cornerRadius(4)
                                        .animation(.easeInOut(duration: 1.5).delay(Double(index) * 0.2), value: showBars)
                                }
                                .frame(width: 150)
                                
                                Text("\(category.percentage, specifier: "%.1f")%")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                                    .frame(width: 40, alignment: .trailing)
                            }
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding()
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                        showBars = true
                    }
                }
            }
        }
    }
}

struct BiggestPurchaseSlide: View {
    let transaction: Transaction
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.red.opacity(0.4), .orange.opacity(0.6), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 25) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.orange)
                
                Text("Your Biggest Purchase")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                if showContent {
                    VStack(spacing: 15) {
                        Text("R\(transaction.amount, specifier: "%.2f")")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                        
                        Text(transaction.description)
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                        
                        if let date = transaction.transactionDate {
                            Text("on \(formatTransactionDate(date))")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding()
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        showContent = true
                    }
                }
            }
        }
    }
    
    private func formatTransactionDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "MMM d"
        return outputFormatter.string(from: date)
    }
}

struct FrequentVendorSlide: View {
    let vendor: (vendor: String, count: Int, amount: Double)
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.teal.opacity(0.4), .cyan.opacity(0.6), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 25) {
                Image(systemName: "repeat.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.teal)
                
                Text("Your Favorite Place")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                if showContent {
                    VStack(spacing: 15) {
                        Text(vendor.vendor)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.teal)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                        
                        Text("\(vendor.count) visits")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Total spent: R\(vendor.amount, specifier: "%.2f")")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding()
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        showContent = true
                    }
                }
            }
        }
    }
}

struct SpendingPatternSlide: View {
    let pattern: (peak: String, quiet: String)
    let average: Double
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.mint.opacity(0.4), .green.opacity(0.6), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 25) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 70))
                    .foregroundColor(.mint)
                
                Text("Your Spending Patterns")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                if showContent {
                    VStack(spacing: 20) {
                        VStack(spacing: 8) {
                            Text("Busiest Day")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                            Text(pattern.peak)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.mint)
                        }
                        
                        VStack(spacing: 8) {
                            Text("Quietest Day")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                            Text(pattern.quiet)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                        }
                        
                        VStack(spacing: 8) {
                            Text("Average Transaction")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                            Text("R\(average, specifier: "%.2f")")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding()
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        showContent = true
                    }
                }
            }
        }
    }
}

struct WeekdayWeekendSlide: View {
    let weekdayVsWeekend: (weekday: Double, weekend: Double)
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.yellow.opacity(0.4), .orange.opacity(0.6), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 25) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 70))
                    .foregroundColor(.yellow)
                
                Text("Weekday vs Weekend")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                if showContent {
                    VStack(spacing: 25) {
                        HStack(spacing: 40) {
                            VStack(spacing: 10) {
                                Text("Weekdays")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("R\(weekdayVsWeekend.weekday, specifier: "%.2f")")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.yellow)
                            }
                            
                            VStack(spacing: 10) {
                                Text("Weekends")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("R\(weekdayVsWeekend.weekend, specifier: "%.2f")")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        let total = weekdayVsWeekend.weekday + weekdayVsWeekend.weekend
                        if total > 0 {
                            let weekdayPercent = (weekdayVsWeekend.weekday / total) * 100
                            Text("You spend \(weekdayPercent, specifier: "%.0f")% during weekdays")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding()
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        showContent = true
                    }
                }
            }
        }
    }
}

struct HealthSummarySlide: View {
    let health: (status: String, color: Color, message: String)
    let savingsRate: Double
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [health.color.opacity(0.3), .black],
                center: .center,
                startRadius: 100,
                endRadius: 400
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(health.color)
                
                Text("Financial Health")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                if showContent {
                    VStack(spacing: 20) {
                        HStack {
                            Circle()
                                .fill(health.color)
                                .frame(width: 20, height: 20)
                            Text(health.status)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(health.color)
                        }
                        
                        Text(health.message)
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("Keep tracking your finances to improve your financial health!")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.top, 20)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding()
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        showContent = true
                    }
                }
            }
        }
    }
}

#Preview {
    // Sample transactions for preview
    let sampleTransactions = [
        Transaction(id: "1", accountId: "acc1", type: "DEBIT", transactionType: "CardPurchases", status: "POSTED", description: "Grocery Shopping", amount: -1250.00, currency: "ZAR", postingDate: "2023-09-10", valueDate: "2023-09-10", transactionDate: "2023-09-10", actionDate: "2023-09-10", category: "Groceries", cardNumber: nil, runningBalance: 10000.00, postedOrder: 1),
        Transaction(id: "2", accountId: "acc1", type: "CREDIT", transactionType: "Deposits", status: "POSTED", description: "Salary Deposit", amount: 25000.00, currency: "ZAR", postingDate: "2023-09-01", valueDate: "2023-09-01", transactionDate: "2023-09-01", actionDate: "2023-09-01", category: "Income", cardNumber: nil, runningBalance: 35000.00, postedOrder: 2),
        Transaction(id: "3", accountId: "acc1", type: "DEBIT", transactionType: "CardPurchases", status: "POSTED", description: "Restaurant Bill", amount: -450.00, currency: "ZAR", postingDate: "2023-09-05", valueDate: "2023-09-05", transactionDate: "2023-09-05", actionDate: "2023-09-05", category: "Dining", cardNumber: nil, runningBalance: 9550.00, postedOrder: 3)
    ]
    
    MonthlyReplayView(transactions: sampleTransactions, month: 9, year: 2023)
}
