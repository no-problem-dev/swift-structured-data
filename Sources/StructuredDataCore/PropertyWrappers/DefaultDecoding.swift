/// Supplies the value a field falls back to when the payload does not provide a usable one.
public protocol DefaultValueProvider {
    associatedtype Value: Codable & Sendable
    static var defaultValue: Value { get }
}

/// Substitutes a fallback for one field instead of failing, leaving the rest of the type strict.
///
/// Declaring the tolerance per field, rather than writing an `init(from:)` for the whole type,
/// keeps every other property's decoding as unforgiving as before.
///
/// The substitution is wider than a missing key: it covers an absent key, an explicit null, and a
/// value of the wrong type entirely. All three are swallowed and none is reported, so a payload
/// that has started sending a string where a number belongs will read as the default forever
/// without anything indicating it. Use this where a plausible fallback exists, not to quieten a
/// field you are unsure about.
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
    /// Resolves a wholly absent key to the provider's value, which the wrapper alone cannot do.
    ///
    /// Without this overload the synthesized `init(from:)` would throw on a missing key before the
    /// wrapper was ever constructed.
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
