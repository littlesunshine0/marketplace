import Foundation
import SwiftUI

public extension NumberFormatter {
    static var currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter
    }()
}

public extension View {
    func badgeStyle() -> some View {
        self
            .padding(6)
            .background(Color(.systemGray6))
            .cornerRadius(8)
    }
}
