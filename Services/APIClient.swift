import Foundation

public protocol APIEndpoint {
    var platform: MarketplacePlatform { get }
    var path: String { get }
    var method: String { get }
    var headers: [String: String] { get }
    var body: Data? { get }

    func urlRequest(baseURL: URL) -> URLRequest
}

public extension APIEndpoint {
    func urlRequest(baseURL: URL) -> URLRequest {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.allHTTPHeaderFields = headers
        request.httpBody = body
        return request
    }
}

public enum APIError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case rateLimited
    case decodingError(DecodingError)
    case networkError(URLError)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP Error: \(code)"
        case .rateLimited:
            return "Rate limited. Please try again later."
        case .decodingError:
            return "Failed to decode response"
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}

public protocol APIClientProtocol {
    var baseURL: URL { get }
    var session: URLSession { get }
    var decoder: JSONDecoder { get }

    func request<T: Decodable>(_ endpoint: APIEndpoint, expecting: T.Type) async throws -> T
}

public actor APIClient: APIClientProtocol {

    public let baseURL: URL
    public let session: URLSession
    public let decoder: JSONDecoder
    public let authenticationManager: AuthenticationManaging

    public init(
        baseURL: URL,
        authenticationManager: AuthenticationManaging,
        session: URLSession? = nil,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.baseURL = baseURL
        self.authenticationManager = authenticationManager
        self.decoder = decoder

        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.waitsForConnectivity = true
            config.timeoutIntervalForRequest = 30
            self.session = URLSession(configuration: config)
        }
    }

    public func request<T: Decodable>(_ endpoint: APIEndpoint, expecting: T.Type) async throws -> T {
        try await request(endpoint, expecting: T.self, attempt: 0)
    }

    private func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        expecting: T.Type,
        attempt: Int
    ) async throws -> T {
        var urlRequest = endpoint.urlRequest(baseURL: baseURL)

        Logger.info(
            category: "network",
            "Starting request",
            metadata: [
                "platform": endpoint.platform.rawValue,
                "path": endpoint.path,
                "method": endpoint.method,
                "attempt": "\(attempt + 1)"
            ]
        )

        if let token = try await authenticationManager.validAccessToken(for: endpoint.platform) {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200...299:
                do {
                    let decoded = try decoder.decode(T.self, from: data)
                    Logger.info(
                        category: "network",
                        "Request succeeded",
                        metadata: [
                            "platform": endpoint.platform.rawValue,
                            "path": endpoint.path,
                            "statusCode": "\(httpResponse.statusCode)"
                        ]
                    )
                    return decoded
                } catch let decodingError as DecodingError {
                    Logger.error(
                        category: "network",
                        "Decoding failed",
                        metadata: [
                            "platform": endpoint.platform.rawValue,
                            "path": endpoint.path,
                            "error": String(describing: decodingError)
                        ]
                    )
                    throw APIError.decodingError(decodingError)
                }
            case 401:
                Logger.warning(
                    category: "network",
                    "Unauthorized response; attempting token refresh",
                    metadata: [
                        "platform": endpoint.platform.rawValue,
                        "path": endpoint.path
                    ]
                )

                guard attempt < 1 else { throw APIError.httpError(httpResponse.statusCode) }

                try await authenticationManager.refreshToken(for: endpoint.platform)
                return try await request(endpoint, expecting: T.self, attempt: attempt + 1)
            case 429:
                Logger.warning(
                    category: "network",
                    "Rate limited",
                    metadata: [
                        "platform": endpoint.platform.rawValue,
                        "path": endpoint.path
                    ]
                )
                throw APIError.rateLimited
            default:
                Logger.error(
                    category: "network",
                    "HTTP error",
                    metadata: [
                        "platform": endpoint.platform.rawValue,
                        "path": endpoint.path,
                        "statusCode": "\(httpResponse.statusCode)"
                    ]
                )
                throw APIError.httpError(httpResponse.statusCode)
            }
        } catch let urlError as URLError {
            Logger.error(
                category: "network",
                "Network error",
                metadata: [
                    "platform": endpoint.platform.rawValue,
                    "path": endpoint.path,
                    "error": urlError.localizedDescription
                ]
            )
            throw APIError.networkError(urlError)
        }
    }
}
