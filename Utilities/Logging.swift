import Foundation

public enum LogLevel: String {
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

public struct LogEvent {
    public let level: LogLevel
    public let category: String
    public let message: String
    public let metadata: [String: String]
    public let timestamp: Date

    public init(
        level: LogLevel,
        category: String,
        message: String,
        metadata: [String: String] = [:],
        timestamp: Date = Date()
    ) {
        self.level = level
        self.category = category
        self.message = message
        self.metadata = metadata
        self.timestamp = timestamp
    }
}

public enum Logger {
    public static func log(_ event: LogEvent) {
        let metadataString: String

        if event.metadata.isEmpty {
            metadataString = "{}"
        } else if let jsonData = try? JSONSerialization.data(withJSONObject: event.metadata, options: [.sortedKeys]),
                  let jsonString = String(data: jsonData, encoding: .utf8) {
            metadataString = jsonString
        } else {
            metadataString = event.metadata.map { "\($0):\($1)" }.joined(separator: ",")
        }

        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: event.timestamp)
        print("[\(event.level.rawValue)] \(timestamp) [\(event.category)] \(event.message) \(metadataString)")
    }

    public static func info(category: String, _ message: String, metadata: [String: String] = [:]) {
        log(LogEvent(level: .info, category: category, message: message, metadata: metadata))
    }

    public static func warning(category: String, _ message: String, metadata: [String: String] = [:]) {
        log(LogEvent(level: .warning, category: category, message: message, metadata: metadata))
    }

    public static func error(category: String, _ message: String, metadata: [String: String] = [:]) {
        log(LogEvent(level: .error, category: category, message: message, metadata: metadata))
    }
}
