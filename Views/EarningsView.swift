import SwiftUI

struct EarningsView: View {
    @EnvironmentObject var viewModel: EarningsViewModel

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                header
                summary
                dailyList
            }
            .padding()
            .navigationTitle("Earnings")
        }
    }

    private var header: some View {
        HStack {
            Text("Earnings & Analytics")
                .font(.largeTitle)
                .bold()
            Spacer()
            Picker("Period", selection: $viewModel.selectedPeriod) {
                ForEach(EarningsPeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            Button("Refresh") { Task { await viewModel.refresh() } }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let summary = viewModel.summary {
                HStack(spacing: 12) {
                    earningCard(title: "Gross Sales", amount: summary.totalGrossSales, color: .blue, icon: "arrow.up.right")
                    earningCard(title: "Fees", amount: summary.totalFees, color: .red, icon: "banknote")
                    earningCard(title: "Net", amount: summary.totalNetEarnings, color: .green, icon: "dollarsign.circle")
                }

                Section("By Platform") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(summary.platformBreakdown.keys.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { platform in
                            if let breakdown = summary.platformBreakdown[platform] {
                                HStack {
                                    Label(platform.rawValue, systemImage: icon(for: platform))
                                    Spacer()
                                    Text("$\(breakdown.grossSales, format: .currency(code: "USD"))")
                                }
                            }
                        }
                    }
                }
            } else {
                ProgressView("Calculating earnings...")
            }
        }
    }

    private var dailyList: some View {
        Section("Daily Breakdown") {
            List(viewModel.daily) { day in
                HStack {
                    Text(day.date, style: .date)
                    Spacer()
                    Text("$\(day.grossSales, format: .currency(code: "USD"))")
                    StatusBadge(text: "\(day.orderCount) orders", color: .blue)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func earningCard(title: String, amount: Decimal, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .foregroundColor(color)
            Text("$\(amount, format: .currency(code: "USD"))")
                .font(.title3)
                .bold()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    private func icon(for platform: MarketplacePlatform) -> String {
        switch platform {
        case .ebay: return "e.circle.fill"
        case .mercari: return "m.circle.fill"
        case .facebook: return "f.circle.fill"
        }
    }
}
