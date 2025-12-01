import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct InventoryView: View {
    @EnvironmentObject var viewModel: InventoryViewModel

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                header
                content
            }
            .padding()
            .navigationTitle("Inventory")
            .toolbar { toolbar }
            .sheet(isPresented: $viewModel.isPresentingPOS) {
                PointOfSaleSheet(product: viewModel.selection, onComplete: { Task { await viewModel.refresh() } })
                    .presentationDetents([.medium, .large])
            }
            .task { await viewModel.refresh() }
        }
    }

    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Button {
                Task { await viewModel.createDraft() }
            } label: {
                Label("New", systemImage: "plus")
            }
            Button {
                Task { await viewModel.publishSelection(to: MarketplacePlatform.allCases) }
            } label: {
                Label("Publish", systemImage: "paperplane")
            }
            Button {
                Task { await viewModel.runPriceCheck() }
            } label: {
                Label("Price Check", systemImage: "chart.bar.xaxis")
            }
            .disabled(viewModel.selection == nil)
        }
    }

    private var header: some View {
        HStack {
            Text("Inventory Management")
                .font(.largeTitle)
                .bold()
            Spacer()
            TextField("Search products", text: $viewModel.searchTerm)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 260)
        }
    }

    private var content: some View {
        HStack(spacing: 16) {
            productTable
            Divider()
            detailPane
        }
    }

    private var productTable: some View {
        List(selection: $viewModel.selection) {
            ForEach(viewModel.filteredProducts) { product in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(product.title)
                            .font(.headline)
                        Spacer()
                        if let status = viewModel.badgeStatus(for: product) {
                            StatusBadge(text: status.rawValue.capitalized, color: statusColor(status))
                        }
                    }
                    Text(product.description)
                        .font(.subheadline)
                        .lineLimit(2)
                        .foregroundColor(.secondary)
                    HStack {
                        Text("$\(product.price, format: .currency(code: "USD"))")
                        Text("Qty: \(product.quantity)")
                            .foregroundColor(.secondary)
                        Spacer()
                        platformIcons(for: product)
                    }
                    .font(.caption)
                }
                .padding(.vertical, 4)
                .tag(product)
            }
        }
        .listStyle(.inset)
        .frame(minWidth: 320, maxWidth: 480)
    }

    private func platformIcons(for product: Product) -> some View {
        let listings = viewModel.platformListings.filter { $0.productId == product.id }
        return HStack(spacing: 6) {
            ForEach(listings) { listing in
                Image(systemName: icon(for: listing.platform))
                    .foregroundColor(.blue)
            }
        }
    }

    private var detailPane: some View {
        Group {
            if let product = viewModel.selection {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(product.title)
                            .font(.title2)
                            .bold()
                        Spacer()
                        Button("Publish All") {
                            Task { await viewModel.publishSelection(to: MarketplacePlatform.allCases) }
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    gallery(for: product)

                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                        GridRow {
                            Label("Price", systemImage: "dollarsign.circle")
                            Text("$\(product.price, format: .currency(code: "USD"))")
                        }
                        GridRow {
                            Label("Quantity", systemImage: "number")
                            Text("\(product.quantity)")
                        }
                        GridRow {
                            Label("Category", systemImage: "tag")
                            Text(product.category)
                        }
                        GridRow {
                            Label("Updated", systemImage: "clock.arrow.circlepath")
                            Text(product.updatedAt, style: .date)
                        }
                    }

                    Divider()

                    HStack {
                        Button("Automated Price Check") { Task { await viewModel.runPriceCheck() } }
                            .disabled(viewModel.isRunningPriceCheck)
                        Button("Point of Sale") { viewModel.isPresentingPOS = true }
                        Button(role: .destructive, action: { Task { await viewModel.deleteSelection() } }) {
                            Text("Delete")
                        }
                    }
                }
            } else {
                VStack {
                    Spacer()
                    Text("Select a product to see details")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func gallery(for product: Product) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if product.images.isEmpty {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .overlay { Image(systemName: "photo.on.rectangle").foregroundColor(.gray) }
                } else {
                    ForEach(product.images) { image in
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 120, height: 120)
                            .overlay {
                                if let data = image.data {
                                    platformImage(from: data)
                                        .resizable()
                                        .scaledToFill()
                                        .clipped()
                                } else {
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                }
                            }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func icon(for platform: MarketplacePlatform) -> String {
        switch platform {
        case .ebay: return "e.circle.fill"
        case .mercari: return "m.circle.fill"
        case .facebook: return "f.circle.fill"
        }
    }

    @ViewBuilder
    private func platformImage(from data: Data) -> some View {
        #if canImport(UIKit)
        if let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
        } else {
            Image(systemName: "photo")
        }
        #else
        Image(systemName: "photo")
        #endif
    }

    private func statusColor(_ status: PlatformListing.ListingStatus) -> Color {
        switch status {
        case .active: return .green
        case .draft: return .gray
        case .paused: return .orange
        case .sold: return .blue
        case .expired, .archived: return .gray
        }
    }
}

struct PointOfSaleSheet: View {
    var product: Product?
    var onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var quantity: Int = 1
    @State private var buyerName: String = "Walk-in"

struct InventoryView: View {
    @EnvironmentObject var listingService: ListingService
    @State private var showCreateListing = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(listingService.products) { product in
                    VStack(alignment: .leading) {
                        Text(product.title)
                            .font(.headline)
                        Text("$\(product.price as NSNumber, formatter: NumberFormatter.currency)")
                            .font(.subheadline)
                        HStack {
                            ForEach(listingService.platformListings.filter { $0.productId == product.id }) { listing in
                                Text(listing.platform.rawValue)
                                    .font(.caption)
                                    .padding(4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Inventory")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showCreateListing = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateListing) {
                CreateListingView()
                    .environmentObject(listingService)
            }
            .task {
                await listingService.loadProducts()
            }
        }
    }
}

struct CreateListingView: View {
    @EnvironmentObject var listingService: ListingService
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var price: Decimal = 0
    @State private var quantity = 1
    @State private var selectedPlatforms: Set<MarketplacePlatform> = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Sale Details") {
                    TextField("Buyer", text: $buyerName)
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...100)
                    if let price = product?.price {
                        Text("Total: $\(price * Decimal(quantity), format: .currency(code: "USD"))")
                    }
                }
            }
            .navigationTitle("POS")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Complete") {
                        onComplete()
                        dismiss()
                    }
                }
            }
        }
    }
                Section("Product Details") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                    TextField("Price", value: $price, formatter: NumberFormatter.currency)
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...1000)
                }

                Section("Publish To") {
                    ForEach(MarketplacePlatform.allCases, id: \.self) { platform in
                        Toggle(platform.rawValue, isOn: .init(
                            get: { selectedPlatforms.contains(platform) },
                            set: { isOn in
                                if isOn { selectedPlatforms.insert(platform) } else { selectedPlatforms.remove(platform) }
                            }
                        ))
                    }
                }
            }
            .navigationTitle("Create Listing")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createListing() }
                        .disabled(title.isEmpty || selectedPlatforms.isEmpty)
                }
            }
        }
    }

    private func createListing() {
        Task {
            let product = Product(
                id: UUID(),
                title: title,
                description: description,
                price: price,
                quantity: quantity,
                category: "General",
                condition: .good,
                images: [],
                tags: [],
                createdAt: Date(),
                updatedAt: Date()
            )

            do {
                try await listingService.createProduct(product)
                try await listingService.publishToAllPlatforms(product, platforms: Array(selectedPlatforms))
                dismiss()
            } catch {
                // In a real app we would surface the error; here we just log it.
                print("Failed to create listing: \(error)")
            }
        }
    }
}
