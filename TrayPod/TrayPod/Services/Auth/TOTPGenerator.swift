import Foundation
import CryptoKit

/// Generates Spotify TOTP codes using secrets fetched from GitHub mirrors.
/// Implements the XOR transform + HMAC-SHA1 TOTP (RFC 6238) used by Spotify's web player auth.
struct TOTPGenerator {

    enum TOTPError: Error, LocalizedError {
        case secretFetchFailed
        case noSecretsAvailable

        var errorDescription: String? {
            switch self {
            case .secretFetchFailed: return "Failed to fetch TOTP secrets from all mirrors"
            case .noSecretsAvailable: return "No TOTP secrets available"
            }
        }
    }

    struct TOTPResult {
        let code: String    // 6-digit TOTP code
        let version: String // Version key from secret dictionary
    }

    // MARK: - Secret Sources

    /// GitHub mirrors hosting the rotating secret dictionary
    private static let secretURLs = [
        "https://github.com/xyloflake/spot-secrets-go/blob/main/secrets/secretDict.json?raw=true",
        "https://github.com/Thereallo1026/spotify-secrets/blob/main/secrets/secretDict.json?raw=true",
    ]

    /// Hardcoded fallback if all mirrors are unreachable
    private static let fallbackSecret: [UInt8] = [
        70, 60, 33, 57, 92, 120, 90, 33, 32, 62, 62, 55, 126, 93, 66, 35, 108, 68
    ]
    private static let fallbackVersion = "18"

    // In-memory cache
    private static var cachedSecret: (version: String, secret: [UInt8])?
    private static var cacheTimestamp: Date?
    private static let cacheTTL: TimeInterval = 3600 // Re-fetch hourly

    // MARK: - Public API

    /// Generate a TOTP code for Spotify authentication
    static func generate() async throws -> TOTPResult {
        let (version, secret) = try await getSecret()
        let key = transformSecret(secret)
        let code = generateTOTP(key: key)
        return TOTPResult(code: code, version: version)
    }

    // MARK: - Secret Management

    private static func getSecret() async throws -> (String, [UInt8]) {
        // Check cache
        if let cached = cachedSecret,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheTTL {
            return (cached.version, cached.secret)
        }

        // Try fetching from mirrors
        if let result = try? await fetchLatestSecret() {
            cachedSecret = result
            cacheTimestamp = Date()
            return result
        }

        // Fall back to hardcoded secret
        print("[TOTPGenerator] All mirrors failed, using fallback secret v\(fallbackVersion)")
        return (fallbackVersion, fallbackSecret)
    }

    private static func fetchLatestSecret() async throws -> (String, [UInt8]) {
        for urlString in secretURLs {
            guard let url = URL(string: urlString) else { continue }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else { continue }

                // Parse as { "version": [byte, byte, ...], ... }
                guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: [Int]] else {
                    continue
                }

                // Select the highest version number
                guard let best = dict
                    .compactMap({ (key, value) -> (Int, String, [UInt8])? in
                        guard let ver = Int(key) else { return nil }
                        return (ver, key, value.map { UInt8(clamping: $0) })
                    })
                    .max(by: { $0.0 < $1.0 }) else {
                    continue
                }

                print("[TOTPGenerator] Fetched secret v\(best.1) from \(url.host ?? "")")
                return (best.1, best.2)
            } catch {
                continue
            }
        }

        throw TOTPError.secretFetchFailed
    }

    // MARK: - XOR Transform

    /// XOR transform: transformed[i] = secret[i] ^ ((i % 33) + 9)
    /// Then concatenate decimal string representations → UTF-8 bytes = HMAC key
    private static func transformSecret(_ secret: [UInt8]) -> Data {
        var transformed = [UInt8](repeating: 0, count: secret.count)
        for i in 0..<secret.count {
            transformed[i] = secret[i] ^ UInt8((i % 33) + 9)
        }

        let joined = transformed.map { String($0) }.joined()
        return joined.data(using: .utf8)!
    }

    // MARK: - TOTP (RFC 6238)

    /// Standard TOTP: HMAC-SHA1, 30-second period, 6-digit code
    private static func generateTOTP(key: Data) -> String {
        let period: UInt64 = 30
        let counter = UInt64(Date().timeIntervalSince1970) / period

        // Counter as big-endian 8-byte message
        var counterBE = counter.bigEndian
        let counterData = Data(bytes: &counterBE, count: 8)

        // HMAC-SHA1
        let symmetricKey = SymmetricKey(data: key)
        let hmac = HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: symmetricKey)
        let hmacBytes = Array(hmac)

        // Dynamic truncation (RFC 4226 §5.4)
        let offset = Int(hmacBytes[hmacBytes.count - 1] & 0x0f)
        let binCode = (UInt32(hmacBytes[offset]) & 0x7f) << 24
            | (UInt32(hmacBytes[offset + 1]) & 0xff) << 16
            | (UInt32(hmacBytes[offset + 2]) & 0xff) << 8
            | (UInt32(hmacBytes[offset + 3]) & 0xff)

        let code = Int(binCode % 1_000_000)
        return String(format: "%06d", code)
    }
}
