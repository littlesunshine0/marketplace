import Foundation
import SwiftUI

@MainActor
final class InventoryViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var platformListings: [PlatformListing] = []
    @Published var selection: Product?
    @Published var isPresentingPOS = false
    @Published var isRunningPriceCheck = false
    @Published var showGallery = false
    @Published var searchTerm: String = ""

    private let listingService: ListingService
    private let priceCheckService: PriceCheckServiceProtocol
    private let notifications: AppNotificationCenter

    init(listingService: ListingService, priceCheckService: PriceCheckServiceProtocol, notifications: AppNotificationCenter) {
        self.listingService = listingService
        self.priceCheckService = priceCheckService
        self.notifications = notifications

        Task { await refresh() }
    }

    var filteredProducts: [Product] {
        guard !searchTerm.isEmpty else { return products }
        return products.filter { product in
            product.title.localizedCaseInsensitiveContains(searchTerm) ||
            product.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchTerm) })
        }
    }

    func refresh() async {
        await listingService.loadProducts()
        products = listingService.products
        platformListings = listingService.platformListings
        if selection == nil { selection = products.first }
    }

    func createDraft() async {
        let newProduct = Product(
            id: UUID(),
            title: "New Draft",
            description: "",
            price: 0,
            quantity: 1,
            category: "General",
            condition: .good,
            images: [],
            tags: [],
            createdAt: Date(),
            updatedAt: Date()
        )
        try? await listingService.createProduct(newProduct)
        await refresh()
        selection = newProduct
        notifications.push(AppNotification(title: "Draft created", message: "Add details to publish across platforms.", level: .info))
    }

    func update(product: Product) async {
        try? await listingService.updateProduct(product)
        await refresh()
        notifications.push(AppNotification(title: "Product saved", message: product.title, level: .success))
    }

    func deleteSelection() async {
        guard let product = selection else { return }
        try? await listingService.deleteProduct(product.id)
        notifications.push(AppNotification(title: "Product deleted", message: product.title, level: .warning))
        await refresh()
        selection = products.first
    }

    func publishSelection(to platforms: [MarketplacePlatform]) async {
        guard let product = selection else { return }
        do {
            try await listingService.publishToAllPlatforms(product, platforms: platforms)
            notifications.push(AppNotification(title: "Published", message: "Sent to \(platforms.map { $0.rawValue }.joined(separator: ", "))", level: .success))
            await refresh()
        } catch {
            notifications.push(AppNotification(title: "Publish failed", message: error.localizedDescription, level: .error))
        }
    }

    func runPriceCheck() async {
        guard var product = selection else { return }
        isRunningPriceCheck = true
        let result = await priceCheckService.suggestPrice(for: product)
        isRunningPriceCheck = false
        product.price = result.suggestedPrice
        product.updatedAt = Date()
        notifications.push(AppNotification(title: "Price check", message: result.rationale, level: .info))
        try? await listingService.updateProduct(product)
        await refresh()
        selection = product
    }

    func badgeStatus(for product: Product) -> PlatformListing.ListingStatus? {
        guard let listing = platformListings.first(where: { $0.productId == product.id }) else { return nil }
        return listing.status
    }
}
