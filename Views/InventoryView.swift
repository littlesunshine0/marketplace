import SwiftUI

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
