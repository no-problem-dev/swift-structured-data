/// Supplies a fallback used when a key is absent or null.
public protocol DefaultValueProvider {
    associatedtype Value: Codable & Sendable
    static var defaultValue: Value { get }
}

/// Opt-in default for a single property, applied when the key is missing or null.
///
/// Tolerance is declared per field rather than baked into the type's
/// `init(from:)`, so the default remains strict everywhere else.
@propertyWrapper
public struct Default<Provider: DefaultValueProvider>: Codable, Sendable {
    public var wrappedValue: Provider.Value

    public init(wrappedValue: Provider.Value) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        wrappedValue = (try? container.decode(Provider.Value.self)) ?? Provider.defaultValue
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

extension Default: Equatable where Provider.Value: Equatable {}
extension Default: Hashable where Provider.Value: Hashable {}

public extension KeyedDecodingContainer {
    /// Resolves a missing key to the provider's default instead of throwing.
    func decode<Provider>(_ type: Default<Provider>.Type, forKey key: Key) throws -> Default<Provider> {
        try decodeIfPresent(type, forKey: key) ?? Default(wrappedValue: Provider.defaultValue)
    }
}

public enum DefaultProviders {
    public struct False: DefaultValueProvider { public static var defaultValue: Bool { false } }
    public struct True: DefaultValueProvider { public static var defaultValue: Bool { true } }
    public struct Zero: DefaultValueProvider { public static var defaultValue: Int { 0 } }
    public struct EmptyString: DefaultValueProvider { public static var defaultValue: String { "" } }
    public struct EmptyArray<Element: Codable & Sendable>: DefaultValueProvider {
        public static var defaultValue: [Element] { [] }
    }
}

public typealias DefaultFalse = Default<DefaultProviders.False>
public typealias DefaultTrue = Default<DefaultProviders.True>
public typealias DefaultZero = Default<DefaultProviders.Zero>
public typealias DefaultEmptyString = Default<DefaultProviders.EmptyString>
public typealias DefaultEmptyArray<Element: Codable & Sendable> = Default<DefaultProviders.EmptyArray<Element>>
