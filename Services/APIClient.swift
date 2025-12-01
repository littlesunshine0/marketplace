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
    associatedtype Response: Decodable

    var baseURL: URL { get }
    var session: URLSession { get }

    func request<T: Decodable>(_ endpoint: APIEndpoint, expecting: T.Type) async throws -> T
}

public actor APIClient: APIClientProtocol {
    public typealias Response = Decodable

    public let baseURL: URL
    public let session: URLSession
    public let authenticationManager: AuthenticationManager

    public init(baseURL: URL, authenticationManager: AuthenticationManager) {
        self.baseURL = baseURL
        self.authenticationManager = authenticationManager

        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    public func request<T: Decodable>(_ endpoint: APIEndpoint, expecting: T.Type) async throws -> T {
        var urlRequest = endpoint.urlRequest(baseURL: baseURL)

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
                    return try JSONDecoder().decode(T.self, from: data)
                } catch let decodingError as DecodingError {
                    throw APIError.decodingError(decodingError)
                }
            case 401:
                try await authenticationManager.refreshToken(for: endpoint.platform)
                return try await request(endpoint, expecting: T.self)
            case 429:
                throw APIError.rateLimited
            default:
                throw APIError.httpError(httpResponse.statusCode)
            }
        } catch let urlError as URLError {
            throw APIError.networkError(urlError)
        }
    }
}
