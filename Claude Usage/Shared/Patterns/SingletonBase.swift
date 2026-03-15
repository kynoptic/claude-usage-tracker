//
//  SingletonBase.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-03-14.
//

import Foundation

/// Protocol to document and enforce the singleton pattern.
///
/// Use this protocol to make the singleton pattern explicit in your code. It is lightweight and doesn't force
/// inheritance—just adopt it alongside `@MainActor` and provide a `static let shared` instance.
///
/// # Examples
///
/// Minimal observable service:
/// ```swift
/// @MainActor
/// final class KeychainService: Singleton {
///     static let shared = KeychainService()
///
///     private init() {}
///
///     func loadToken() throws -> String { /* ... */ }
/// }
/// ```
///
/// Observable manager with `@Published` state:
/// ```swift
/// @MainActor
/// final class ProfileManager: Singleton, ObservableObject {
///     static let shared = ProfileManager()
///
///     @Published var activeProfile: Profile?
///
///     private init() {}
///
///     func activateProfile(_ id: UUID) { /* ... */ }
/// }
/// ```
///
/// Non-UI service without `ObservableObject`:
/// ```swift
/// final class LoggingService: Singleton {
///     static let shared = LoggingService()
///
///     private init() {}
///
///     func log(_ message: String) { /* ... */ }
/// }
/// ```
///
/// # Why adopt this protocol?
///
/// - **Clarity:** Makes the singleton pattern explicit to readers and reviewers.
/// - **Consistency:** Enforces `static let shared` method signature across the codebase.
/// - **Documentation:** Serves as a waypoint to the singleton pattern ADR (ADR-007).
///
/// Adoption is optional—existing singletons are grandfathered in. New services should adopt it to signal intent.
///
public protocol Singleton: AnyObject {
    associatedtype T = Self
    static var shared: T { get }
}
