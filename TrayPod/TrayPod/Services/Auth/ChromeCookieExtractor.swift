import Foundation
import CommonCrypto
import SQLite3

/// Extracts and decrypts Spotify cookies (sp_dc, sp_t) from Chrome's cookie database on macOS.
/// Uses Keychain to get Chrome's encryption password, PBKDF2 for key derivation, AES-128-CBC for decryption.
struct ChromeCookieExtractor {

    struct CookieResult {
        let spDc: String
        let spT: String?
    }

    enum ExtractionError: Error, LocalizedError {
        case keychainFailed(String)
        case cookieDBNotFound
        case cookieDBCopyFailed
        case sqliteOpenFailed(String)
        case noCookiesFound
        case decryptionFailed(String)

        var errorDescription: String? {
            switch self {
            case .keychainFailed(let msg): return "Keychain access failed: \(msg)"
            case .cookieDBNotFound: return "Chrome cookie database not found"
            case .cookieDBCopyFailed: return "Failed to copy cookie database"
            case .sqliteOpenFailed(let msg): return "SQLite error: \(msg)"
            case .noCookiesFound: return "No Spotify cookies found in Chrome"
            case .decryptionFailed(let msg): return "Cookie decryption failed: \(msg)"
            }
        }
    }

    /// Extract sp_dc and sp_t cookies from Chrome's cookie database
    static func extractCookies() throws -> CookieResult {
        // 1. Get Chrome's encryption password from Keychain
        let password = try getChromeKeychainPassword()

        // 2. Derive AES-128 key via PBKDF2
        let key = try deriveKey(from: password)

        // 3. Copy cookie DB to temp location (avoids WAL lock conflicts)
        let tempDBPath = try copyCookieDB()
        defer { try? FileManager.default.removeItem(atPath: tempDBPath) }

        // 4. Query for Spotify cookies
        let encryptedCookies = try querySpotifyCookies(dbPath: tempDBPath)

        // 5. Decrypt cookies
        var spDc: String?
        var spT: String?

        for (name, encryptedValue) in encryptedCookies {
            if let decrypted = try? decrypt(encryptedValue: encryptedValue, key: key) {
                if name == "sp_dc" { spDc = decrypted }
                if name == "sp_t" { spT = decrypted }
            }
        }

        guard let dc = spDc else {
            throw ExtractionError.noCookiesFound
        }

        return CookieResult(spDc: dc, spT: spT)
    }

    // MARK: - Keychain

    private static func getChromeKeychainPassword() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-w", "-a", "Chrome", "-s", "Chrome Safe Storage"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ExtractionError.keychainFailed("security command exited with status \(process.terminationStatus)")
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let password = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !password.isEmpty else {
            throw ExtractionError.keychainFailed("Empty password returned")
        }

        return password
    }

    // MARK: - Key Derivation (PBKDF2)

    private static func deriveKey(from password: String) throws -> Data {
        let salt = "saltysalt".data(using: .utf8)!
        let keyLength = 16 // AES-128
        let iterations: UInt32 = 1003

        var derivedKey = Data(count: keyLength)
        let passwordData = password.data(using: .utf8)!

        let status = derivedKey.withUnsafeMutableBytes { keyBytes in
            passwordData.withUnsafeBytes { passwordBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                        iterations,
                        keyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            throw ExtractionError.decryptionFailed("PBKDF2 failed with status \(status)")
        }

        return derivedKey
    }

    // MARK: - Cookie DB Copy

    private static func copyCookieDB() throws -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser

        // Chrome 96+ stores cookies in Network/ subdirectory
        let primaryPath = home.appendingPathComponent("Library/Application Support/Google/Chrome/Default/Network/Cookies")
        // Older Chrome stores cookies directly in Default/
        let fallbackPath = home.appendingPathComponent("Library/Application Support/Google/Chrome/Default/Cookies")

        let sourcePath: String
        if FileManager.default.fileExists(atPath: primaryPath.path) {
            sourcePath = primaryPath.path
        } else if FileManager.default.fileExists(atPath: fallbackPath.path) {
            sourcePath = fallbackPath.path
        } else {
            throw ExtractionError.cookieDBNotFound
        }

        let tempPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("traypod_cookies_\(UUID().uuidString).db").path

        do {
            try FileManager.default.copyItem(atPath: sourcePath, toPath: tempPath)
        } catch {
            throw ExtractionError.cookieDBCopyFailed
        }

        return tempPath
    }

    // MARK: - SQLite Query

    private static func querySpotifyCookies(dbPath: String) throws -> [(String, Data)] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            let errMsg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(db)
            throw ExtractionError.sqliteOpenFailed(errMsg)
        }
        defer { sqlite3_close(db) }

        let query = """
            SELECT name, encrypted_value FROM cookies
            WHERE host_key LIKE '%spotify.com%'
            AND name IN ('sp_dc', 'sp_t')
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            throw ExtractionError.sqliteOpenFailed(errMsg)
        }
        defer { sqlite3_finalize(stmt) }

        var cookies: [(String, Data)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let namePtr = sqlite3_column_text(stmt, 0) else { continue }
            let name = String(cString: namePtr)

            let blobLength = sqlite3_column_bytes(stmt, 1)
            guard blobLength > 0, let blobPtr = sqlite3_column_blob(stmt, 1) else { continue }
            let encryptedValue = Data(bytes: blobPtr, count: Int(blobLength))

            cookies.append((name, encryptedValue))
        }

        if cookies.isEmpty {
            throw ExtractionError.noCookiesFound
        }

        return cookies
    }

    // MARK: - AES-128-CBC Decryption

    private static func decrypt(encryptedValue: Data, key: Data) throws -> String {
        // macOS Chrome prefixes encrypted values with "v10" (3 bytes)
        guard encryptedValue.count > 3 else {
            throw ExtractionError.decryptionFailed("Encrypted value too short")
        }

        let prefix = String(data: encryptedValue.prefix(3), encoding: .utf8)
        guard prefix == "v10" else {
            // Might be unencrypted plaintext
            if let plain = String(data: encryptedValue, encoding: .utf8) {
                return plain
            }
            throw ExtractionError.decryptionFailed("Unknown encryption prefix")
        }

        let ciphertext = encryptedValue.dropFirst(3)

        // IV: 16 space characters (0x20)
        let iv = Data(repeating: 0x20, count: 16)

        let bufferSize = ciphertext.count + kCCBlockSizeAES128
        var decryptedData = Data(count: bufferSize)
        var decryptedLength = 0

        let status = decryptedData.withUnsafeMutableBytes { decryptedBytes in
            ciphertext.withUnsafeBytes { ciphertextBytes in
                key.withUnsafeBytes { keyBytes in
                    iv.withUnsafeBytes { ivBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress, key.count,
                            ivBytes.baseAddress,
                            ciphertextBytes.baseAddress, ciphertext.count,
                            decryptedBytes.baseAddress, bufferSize,
                            &decryptedLength
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else {
            throw ExtractionError.decryptionFailed("AES decrypt failed with status \(status)")
        }

        decryptedData.count = decryptedLength

        guard let result = String(data: decryptedData, encoding: .utf8) else {
            throw ExtractionError.decryptionFailed("Decrypted data is not valid UTF-8")
        }

        return result
    }
}
