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
    @EnvironmentObject var earningsService: EarningsService
    @State private var selectedPeriod: EarningsPeriod = .thisMonth

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(EarningsPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                if let summary = earningsService.earningsSummary {
                    VStack(spacing: 12) {
                        EarningCard(title: "Gross Sales", amount: summary.totalGrossSales, color: .blue)
                        EarningCard(title: "Total Fees", amount: summary.totalFees, color: .red)
                        EarningCard(title: "Net Earnings", amount: summary.totalNetEarnings, color: .green)
                    }
                    .padding()

                    Section("By Platform") {
                        VStack(spacing: 8) {
                            ForEach(summary.platformBreakdown.values.sorted(by: { $0.grossSales > $1.grossSales })) { platform in
                                HStack {
                                    Text(platform.platform.rawValue)
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text("$\(platform.grossSales as NSNumber, formatter: NumberFormatter.currency)")
                                            .fontWeight(.semibold)
                                        Text("\(platform.orderCount) orders")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding()

                    Spacer()
                } else {
                    VStack {
                        ProgressView()
                        Text("Loading earnings...")
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Earnings")
            .task {
                await earningsService.calculateEarnings(for: selectedPeriod.dateInterval)
            }
        }
    }
}

struct EarningCard: View {
    let title: String
    let amount: Decimal
    let color: Color

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text("$\(amount as NSNumber, formatter: NumberFormatter.currency)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

enum EarningsPeriod: String, CaseIterable {
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case thisYear = "This Year"

    var dateInterval: DateInterval {
        let now = Date()
        let calendar = Calendar.current

        switch self {
        case .thisWeek:
            let startComponents = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: now)
            let weekStart = calendar.date(from: startComponents) ?? now
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? now
            return DateInterval(start: weekStart, end: weekEnd)
        case .thisMonth:
            let startComponents = calendar.dateComponents([.year, .month], from: now)
            let monthStart = calendar.date(from: startComponents) ?? now
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? now
            return DateInterval(start: monthStart, end: monthEnd)
        case .lastMonth:
            var components = calendar.dateComponents([.year, .month], from: now)
            components.month = (components.month ?? 1) - 1
            let monthStart = calendar.date(from: components) ?? now
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? now
            return DateInterval(start: monthStart, end: monthEnd)
        case .thisYear:
            let startComponents = calendar.dateComponents([.year], from: now)
            let yearStart = calendar.date(from: startComponents) ?? now
            let yearEnd = calendar.date(byAdding: .year, value: 1, to: yearStart) ?? now
            return DateInterval(start: yearStart, end: yearEnd)
        }
    }
}
