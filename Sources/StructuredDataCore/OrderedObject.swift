/// Policy for handling repeated names within a single object.
///
/// RFC 8259 leaves duplicate-name behaviour implementation-defined; this makes
/// the choice explicit at parse time.
public enum DuplicateKeyPolicy: Sendable {
    /// Keep the last occurrence (JavaScript-compatible, the common default).
    case lastWins
    /// Keep the first occurrence.
    case firstWins
    /// Reject the document (I-JSON / RFC 7493 strictness).
    case reject
    /// Preserve every occurrence in source order.
    case preserveAll
}

/// An insertion-order-preserving string-keyed collection.
///
/// JSON/YAML objects are unordered by spec, but preserving source order keeps
/// re-serialization and diffs stable. Lookup returns the first match, matching
/// how decoders resolve keys.
public struct OrderedObject: Sendable, Hashable {
    public private(set) var entries: [(key: String, value: StructuredValue)]

    public init() { entries = [] }

    public init(_ entries: [(key: String, value: StructuredValue)]) {
        self.entries = entries
    }

    /// Builds from a Swift dictionary. Insertion order is unspecified (JSON
    /// objects are unordered), so use the entries initializer when order matters.
    public init(_ dictionary: [String: StructuredValue]) {
        self.entries = dictionary.map { ($0.key, $0.value) }
    }

    public var keys: [String] { entries.map(\.key) }
    public var count: Int { entries.count }
    public var isEmpty: Bool { entries.isEmpty }

    public subscript(key: String) -> StructuredValue? {
        entries.first { $0.key == key }?.value
    }

    public mutating func append(key: String, value: StructuredValue) {
        entries.append((key, value))
    }

    /// Builds an object from raw entries, applying the duplicate-name policy.
    ///
    /// Returns `nil` only when `policy` is `.reject` and a duplicate is present.
    public static func make(
        from raw: [(key: String, value: StructuredValue)],
        policy: DuplicateKeyPolicy
    ) -> OrderedObject? {
        switch policy {
        case .preserveAll:
            return OrderedObject(raw)
        case .reject:
            var seen = Set<String>()
            for entry in raw where !seen.insert(entry.key).inserted { return nil }
            return OrderedObject(raw)
        case .firstWins, .lastWins:
            var order: [String] = []
            var values: [String: StructuredValue] = [:]
            for entry in raw {
                if values[entry.key] == nil { order.append(entry.key) }
                if policy == .lastWins || values[entry.key] == nil {
                    values[entry.key] = entry.value
                }
            }
            return OrderedObject(order.map { ($0, values[$0]!) })
        }
    }

    /// Order-insensitive: JSON/YAML objects are semantically unordered, so two
    /// objects with the same name/value pairs are equal regardless of order.
    /// Insertion order is still preserved for serialization.
    public static func == (lhs: OrderedObject, rhs: OrderedObject) -> Bool {
        guard lhs.entries.count == rhs.entries.count else { return false }
        var rhsMap: [String: StructuredValue] = [:]
        for entry in rhs.entries { rhsMap[entry.key] = entry.value }
        for entry in lhs.entries where rhsMap[entry.key] != entry.value { return false }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        var accumulator = 0
        for entry in entries {
            var entryHasher = Hasher()
            entryHasher.combine(entry.key)
            entryHasher.combine(entry.value)
            accumulator ^= entryHasher.finalize()
        }
        hasher.combine(accumulator)
    }
}

extension OrderedObject: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, StructuredValue)...) {
        self.init(elements.map { ($0.0, $0.1) })
    }
}

extension OrderedObject: Sequence {
    public func makeIterator() -> Array<(key: String, value: StructuredValue)>.Iterator {
        entries.makeIterator()
    }
}
