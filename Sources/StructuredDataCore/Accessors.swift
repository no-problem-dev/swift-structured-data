/// Exploratory, non-throwing access into an untyped document.
///
/// This is sugar layered on top of the type-safe backbone: subscripts never
/// throw and missing paths surface as `.null`, so chains like
/// `value.user.name.string` are safe to write. For strict conversion use
/// ``StructuredValue/decode(_:options:)``; dynamic member lookup is String-based
/// and therefore does not catch typos at compile time.
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

    /// Optionally decodes a child value, returning `nil` on absence or mismatch.
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

/// Key-based typed accessors for object values, with numeric coercion so that a
/// `65.0` delivered where an `Int` is expected still reads (matching how LLM
/// tool arguments often arrive).
extension StructuredValue {
    public func string(_ key: String) -> String? { self[key].stringValue }
    public func bool(_ key: String) -> Bool? { self[key].boolValue }
    public func int(_ key: String) -> Int? { self[key].numberValue?.coercedInt }
    public func double(_ key: String) -> Double? { self[key].numberValue?.double }
    public func array(_ key: String) -> [StructuredValue]? { self[key].arrayValue }
    public func object(_ key: String) -> OrderedObject? { self[key].objectValue }
    public func stringArray(_ key: String) -> [String]? { self[key].arrayValue?.compactMap(\.stringValue) }
    public func has(_ key: String) -> Bool { objectValue?[key] != nil }
    public var keys: [String] { objectValue?.keys ?? [] }
}

extension StructuredNumber {
    /// The value as `Int`, accepting fractional text like `65.0` by truncation.
    public var coercedInt: Int? {
        if let exact = int { return exact }
        let value = double
        return value.isFinite ? Int(value) : nil
    }
}
