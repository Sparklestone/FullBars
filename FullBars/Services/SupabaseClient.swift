import Foundation
import os

/// Lightweight Supabase REST client using URLSession.
/// No third-party dependencies — just plain REST calls with the anon key.
final class SupabaseClient {
    static let shared = SupabaseClient()

    private let logger = Logger(subsystem: "com.fullbars.app", category: "Supabase")
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    // MARK: - Generic REST Methods

    /// INSERT a row into a Supabase table. Returns the inserted row as JSON.
    func insert<T: Encodable>(table: String, row: T) async throws -> Data {
        let url = URL(string: "\(SupabaseConfig.restURL)/\(table)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.addValue("return=representation", forHTTPHeaderField: "Prefer")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(row)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data, context: "INSERT \(table)")
        return data
    }

    /// INSERT multiple rows in a single batch.
    func insertBatch<T: Encodable>(table: String, rows: [T]) async throws {
        guard !rows.isEmpty else { return }

        let url = URL(string: "\(SupabaseConfig.restURL)/\(table)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.addValue("return=minimal", forHTTPHeaderField: "Prefer")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(rows)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data, context: "INSERT BATCH \(table)")
    }

    /// SELECT rows from a Supabase table with optional query parameters.
    func select<T: Decodable>(table: String, query: [String: String] = [:], as type: T.Type) async throws -> T {
        var components = URLComponents(string: "\(SupabaseConfig.restURL)/\(table)")!
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data, context: "SELECT \(table)")

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }

    /// Call an RPC function on Supabase (e.g. match_ads).
    func rpc<P: Encodable, R: Decodable>(function: String, params: P, as type: R.Type) async throws -> R {
        let url = URL(string: "\(SupabaseConfig.rpcURL)/\(function)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(params)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data, context: "RPC \(function)")

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }

    // MARK: - Response Validation

    private func validateResponse(_ response: URLResponse, data: Data, context: String) throws {
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            logger.error("\(context) failed [\(http.statusCode)]: \(body)")
            throw SupabaseError.httpError(statusCode: http.statusCode, body: body)
        }
    }
}

// MARK: - Error Types

enum SupabaseError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, body: String)
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from Supabase"
        case .httpError(let code, let body): return "Supabase error \(code): \(body)"
        case .notConfigured: return "Supabase is not configured"
        }
    }
}
