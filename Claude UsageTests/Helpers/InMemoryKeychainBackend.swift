import Foundation
import Security
@testable import Claude_Usage

/// In-memory Keychain backend for tests. Stores items as dictionaries keyed by (service, account).
/// Avoids macOS Keychain access prompts so tests can run unsigned and headlessly.
final class InMemoryKeychainBackend: KeychainBackend, @unchecked Sendable {
    /// Items stored as (service, account) -> Data
    private var storage: [String: Data] = [:]

    private func storageKey(from query: CFDictionary) -> String? {
        guard let dict = query as? [String: Any],
              let service = dict[kSecAttrService as String] as? String,
              let account = dict[kSecAttrAccount as String] as? String else {
            return nil
        }
        return "\(service)::\(account)"
    }

    func add(_ attributes: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        guard let key = storageKey(from: attributes) else { return errSecParam }
        if storage[key] != nil { return errSecDuplicateItem }
        guard let dict = attributes as? [String: Any],
              let data = dict[kSecValueData as String] as? Data else {
            return errSecParam
        }
        storage[key] = data
        return errSecSuccess
    }

    func update(_ query: CFDictionary, _ attributesToUpdate: CFDictionary) -> OSStatus {
        guard let key = storageKey(from: query) else { return errSecParam }
        guard storage[key] != nil else { return errSecItemNotFound }
        guard let dict = attributesToUpdate as? [String: Any],
              let data = dict[kSecValueData as String] as? Data else {
            return errSecParam
        }
        storage[key] = data
        return errSecSuccess
    }

    func delete(_ query: CFDictionary) -> OSStatus {
        guard let key = storageKey(from: query) else { return errSecParam }
        if storage.removeValue(forKey: key) != nil {
            return errSecSuccess
        }
        return errSecItemNotFound
    }

    func copyMatching(_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        guard let key = storageKey(from: query) else { return errSecParam }
        guard let data = storage[key] else { return errSecItemNotFound }

        // If caller wants data back
        if let dict = query as? [String: Any],
           let returnData = dict[kSecReturnData as String] as? Bool,
           returnData {
            result?.pointee = data as CFTypeRef
        }
        return errSecSuccess
    }

    /// Reset all stored items (for setUp/tearDown).
    func reset() {
        storage.removeAll()
    }
}
