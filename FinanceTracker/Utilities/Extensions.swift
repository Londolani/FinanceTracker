import Foundation
import SwiftUI

// MARK: - Number Formatters
extension NumberFormatter {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = ""
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}

// MARK: - Date Formatters
extension DateFormatter {
    static let transactionDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - Common UI Styles
struct AppTheme {
    static let primaryGradient = LinearGradient(
        colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cardShadow = Color.black.opacity(0.08)
    static let cardRadius: CGFloat = 16
}
