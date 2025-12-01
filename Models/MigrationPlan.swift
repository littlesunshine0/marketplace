import Foundation

public struct MigrationStep: Codable, Equatable, Identifiable {
    public let id: UUID
    public let name: String
    public let appliedAt: Date
    public let description: String
}

public actor MigrationPlanner {
    private(set) var appliedMigrations: [MigrationStep] = []

    public init() {}

    public func apply(_ step: MigrationStep) {
        appliedMigrations.append(step)
        Logger.info(category: "migrations", "Applied migration", metadata: ["name": step.name])
    }
}
