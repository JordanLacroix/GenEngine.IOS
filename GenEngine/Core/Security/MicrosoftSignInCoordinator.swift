import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

@MainActor
final class MicrosoftSignInCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func signIn(authority: String, clientId: String) async throws -> String {
        let baseAuthority = authority.hasSuffix("/v2.0") ? String(authority.dropLast(5)) : authority
        let verifier = Self.randomURLSafeString()
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URL
        let state = Self.randomURLSafeString()
        let redirectURI = "genengine://auth"
        let scope = "openid profile email api://\(clientId)/.default"
        guard var components = URLComponents(string: baseAuthority + "/oauth2/v2.0/authorize") else { throw APIError.invalidURL }
        components.queryItems = [
            .init(name: "client_id", value: clientId),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "response_mode", value: "query"),
            .init(name: "scope", value: scope),
            .init(name: "state", value: state),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
        ]
        guard let authorizationURL = components.url else { throw APIError.invalidURL }

        let callback = try await authenticate(url: authorizationURL)
        guard let returned = URLComponents(url: callback, resolvingAgainstBaseURL: false),
              returned.queryItems?.first(where: { $0.name == "state" })?.value == state,
              let code = returned.queryItems?.first(where: { $0.name == "code" })?.value
        else { throw APIError.transport("Réponse Microsoft invalide.") }

        guard let tokenURL = URL(string: baseAuthority + "/oauth2/v2.0/token") else { throw APIError.invalidURL }
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = [
            "client_id": clientId,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "code_verifier": verifier,
            "scope": scope,
        ].map { key, value in "\(key.urlFormEncoded)=\(value.urlFormEncoded)" }.joined(separator: "&").data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = payload["access_token"] as? String
        else { throw APIError.transport("Microsoft n’a pas délivré de jeton d’accès.") }
        return accessToken
    }

    func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }

    private func authenticate(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "genengine") { callback, error in
                if let callback { continuation.resume(returning: callback) }
                else { continuation.resume(throwing: error ?? APIError.transport("Connexion Microsoft annulée.")) }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            guard session.start() else {
                continuation.resume(throwing: APIError.transport("Impossible d’ouvrir la connexion Microsoft."))
                return
            }
        }
    }

    private static func randomURLSafeString() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URL
    }
}

private extension Data {
    var base64URL: String { base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
}

private extension String {
    var urlFormEncoded: String { addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? self }
}
