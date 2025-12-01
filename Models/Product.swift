import Foundation

public struct Product: Identifiable, Codable, Equatable {
    public let id: UUID
    public var title: String
    public var description: String
    public var price: Decimal
    public var quantity: Int
    public var category: String
    public var condition: Condition
    public var images: [ProductImage]
    public var tags: [String]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        title: String,
        description: String,
        price: Decimal,
        quantity: Int,
        category: String,
        condition: Condition,
        images: [ProductImage],
        tags: [String],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.price = price
        self.quantity = quantity
        self.category = category
        self.condition = condition
        self.images = images
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public enum Condition: String, Codable {
        case new
        case likeNew
        case good
        case fair
        case poor
    }
}

public struct ProductImage: Identifiable, Codable, Equatable {
    public let id: UUID
    public var data: Data?
    public var remoteURL: URL?
    public var order: Int

    public init(id: UUID, data: Data?, remoteURL: URL?, order: Int) {
        self.id = id
        self.data = data
        self.remoteURL = remoteURL
        self.order = order
    }
}
