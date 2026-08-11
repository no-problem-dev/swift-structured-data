/// Exploratory access to an untyped document, where nothing throws and a missing path is simply null.
///
/// Sugar over the type-safe backbone. Subscripts never throw and a path that does not exist
/// surfaces as `.null`, so a chain like `value.user.name.string` is safe to write even when the
/// document is shaped differently than expected — and gives you nil rather than telling you which
/// hop was wrong. Reach for ``StructuredValue/decode(_:options:)`` when a mismatch should be an
/// error. Dynamic member lookup is string-based, so a typo here is not a compile-time failure.
extension StructuredValue {
    public subscript(key: String) -> StructuredValue {
        objectValue?[key] ?? .null
    }

    public subscript(index: Int) -> StructuredValue {
        guard let array = arrayValue, array.indices.contains(index) else { return .null }
        return array[index]
    }

    public subscript(dynamicMember member: String) -> StructuredValue {
        objectValue?[member] ?? .null
    }

    /// Decodes the child at a key, giving nil for a missing key and for any decoding failure alike.
    ///
    /// The failure is swallowed, not reported, so this cannot distinguish "absent" from
    /// "present but malformed". Use ``StructuredValue/decode(_:options:)`` when you need to know.
    public subscript<T: Decodable>(key: String, as type: T.Type) -> T? {
        try? self[key].decode(type)
    }
}

extension StructuredValue {
    public var string: String? { stringValue }
    public var bool: Bool? { boolValue }
    public var int: Int? { numberValue?.coercedInt }
    public var int64: Int64? { numberValue?.int64 }
    public var double: Double? { numberValue?.double }
    public var array: [StructuredValue]? { arrayValue }
    public var object: OrderedObject? { objectValue }
    public var exists: Bool { !isNull }
}

/// Typed lookups on an object, forgiving about how a number was spelled.
///
/// Each method looks a key up on the receiver, which must be an object, and gives nil when the key
/// is absent, the value is null, or the type does not match. The one place they bend is numbers:
/// an `Int` read tolerates `65.0` and `6.5e1`, the shapes that turn up in LLM tool arguments and
/// in JavaScript producers that have no integer type.
extension StructuredValue {
    public func string(_ key: String) -> String? { self[key].stringValue }
    public func bool(_ key: String) -> Bool? { self[key].boolValue }
    /// The integer at a key, accepting fractional and exponent spellings by truncating toward zero.
    public func int(_ key: String) -> Int? { self[key].numberValue?.coercedInt }
    public func double(_ key: String) -> Double? { self[key].numberValue?.double }
    public func array(_ key: String) -> [StructuredValue]? { self[key].arrayValue }
    public func object(_ key: String) -> OrderedObject? { self[key].objectValue }
    /// The string elements of the array at a key, dropping any element that is not a string.
    ///
    /// A mixed array comes back shorter rather than nil, so the count is not evidence of the
    /// source array's length.
    public func stringArray(_ key: String) -> [String]? { self[key].arrayValue?.compactMap(\.stringValue) }
    /// Whether the key is present, counting an explicit null as present.
    public func has(_ key: String) -> Bool { objectValue?[key] != nil }
    /// The keys of this object in source order, or no keys at all when it is not an object.
    public var keys: [String] { objectValue?.keys ?? [] }
}

extension StructuredNumber {
    /// The value as an integer, accepting fractional and exponent spellings by truncating toward zero.
    ///
    /// An exactly-spelled integer is read from the text and keeps full precision. Anything else
    /// goes through `Double` first, so `65.9` becomes `65`, digits past a double's precision are
    /// lost, and a non-finite magnitude gives nil.
    public var coercedInt: Int? {
        if let exact = int { return exact }
        let value = double
        return value.isFinite ? Int(value) : nil
    }
}
