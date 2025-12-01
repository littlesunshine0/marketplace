import Foundation

public struct Order: Identifiable, Codable, Equatable {
    public let id: UUID
    public let platformOrderId: String
    public let platform: MarketplacePlatform
    public let productId: UUID?
    public let buyerName: String
    public var quantity: Int
    public var itemPrice: Decimal
    public var totalAmount: Decimal
    public var fees: OrderFees
    public var status: OrderStatus
    public var createdAt: Date
    public var updatedAt: Date?
    public var estimatedDeliveryAt: Date?
    public var paidAt: Date?
    public var shippedAt: Date?

    public init(
        id: UUID,
        platformOrderId: String,
        platform: MarketplacePlatform,
        productId: UUID?,
        buyerName: String,
        quantity: Int,
        itemPrice: Decimal,
        totalAmount: Decimal,
        fees: OrderFees,
        status: OrderStatus,
        createdAt: Date,
        updatedAt: Date? = nil,
        estimatedDeliveryAt: Date?,
        paidAt: Date?,
        shippedAt: Date?
    ) {
        self.id = id
        self.platformOrderId = platformOrderId
        self.platform = platform
        self.productId = productId
        self.buyerName = buyerName
        self.quantity = quantity
        self.itemPrice = itemPrice
        self.totalAmount = totalAmount
        self.fees = fees
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.estimatedDeliveryAt = estimatedDeliveryAt
        self.paidAt = paidAt
        self.shippedAt = shippedAt
    }
}

public struct OrderFees: Codable, Equatable {
    public let platformFee: Decimal
    public let paymentProcessingFee: Decimal
    public let shippingFee: Decimal?

    public init(
        platformFee: Decimal,
        paymentProcessingFee: Decimal,
        shippingFee: Decimal?
    ) {
        self.platformFee = platformFee
        self.paymentProcessingFee = paymentProcessingFee
        self.shippingFee = shippingFee
    }

    public var totalFees: Decimal {
        platformFee + paymentProcessingFee + (shippingFee ?? 0)
    }
}

public enum OrderStatus: String, Codable {
    case pending
    case paid
    case processing
    case shipped
    case delivered
    case cancelled
    case returned
}
