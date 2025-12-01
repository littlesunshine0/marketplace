import Foundation

public protocol PersistenceManagerProtocol {
    func save<T: Codable>(_ object: T) throws
    func update<T: Codable>(_ object: T) throws
    func fetch<T: Codable>(_ type: T.Type) throws -> [T]
    func delete<T>(_ type: T.Type, id: UUID) throws
}

public actor PersistenceManager: PersistenceManagerProtocol {
    private var store: [String: [UUID: Data]] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init() {}

    public func save<T: Codable>(_ object: T) throws {
        guard let identifiable = object as? Identifiable else { return }
        let data = try encoder.encode(object)
        var bucket = store[key(for: T.self)] ?? [:]
        if let id = identifiable.id as? UUID {
            bucket[id] = data
        }
        store[key(for: T.self)] = bucket
    }

    public func update<T: Codable>(_ object: T) throws {
        try save(object)
    }

    public func fetch<T: Codable>(_ type: T.Type) throws -> [T] {
        let bucket = store[key(for: T.self)] ?? [:]
        return try bucket.values.map { try decoder.decode(T.self, from: $0) }
    }

    public func delete<T>(_ type: T.Type, id: UUID) throws {
        var bucket = store[key(for: T.self)] ?? [:]
        bucket[id] = nil
        store[key(for: T.self)] = bucket
    }

    private func key<T>(for type: T.Type) -> String {
        String(reflecting: type)
    }
}
