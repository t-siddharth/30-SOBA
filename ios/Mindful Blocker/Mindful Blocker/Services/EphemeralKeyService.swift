//
//  EphemeralKeyService.swift
//  Mindful Blocker
//

import Foundation

actor EphemeralKeyService {
    // MARK: - Configuration
    // Change this to your Mac's local IP address (e.g., "192.168.1.100")
    // Find your IP by running: ipconfig getifaddr en0
    private static let serverHost = "192.168.0.52"
    private static let serverPort = "8000"

    private var serverURL: URL {
        URL(string: "http://\(Self.serverHost):\(Self.serverPort)/session")!
    }

    struct SessionResponse: Decodable {
        struct ClientSecret: Decodable {
            let value: String
        }
        let client_secret: ClientSecret
    }

    enum EphemeralKeyError: Error {
        case invalidResponse
        case networkError(Error)
        case decodingError(Error)
    }

    func fetchEphemeralKey() async throws -> String {
        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw EphemeralKeyError.invalidResponse
            }

            let sessionResponse = try JSONDecoder().decode(SessionResponse.self, from: data)
            return sessionResponse.client_secret.value
        } catch let error as EphemeralKeyError {
            throw error
        } catch let error as DecodingError {
            throw EphemeralKeyError.decodingError(error)
        } catch {
            throw EphemeralKeyError.networkError(error)
        }
    }
}
