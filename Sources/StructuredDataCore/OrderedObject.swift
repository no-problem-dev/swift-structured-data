/// What to do when one object names the same key twice.
///
/// RFC 8259 leaves this to the implementation, which means a document with a repeated name has no
/// single correct reading. Choosing here makes the reading explicit at parse time instead of
/// leaving it to whichever code happens to look the key up.
public enum DuplicateKeyPolicy: Sendable {
    /// Keeps the last occurrence, matching what JavaScript's own parser does.
    case lastWins
    /// Keeps the first occurrence.
    case firstWins
    /// Rejects the whole document, as RFC 7493 (I-JSON) requires.
    case reject
    /// Keeps every occurrence in source order, leaving the ambiguity in the tree.
    ///
    /// Lookups then return the first of the repeated entries while serialization writes all of
    /// them, so a round trip preserves the duplication rather than resolving it.
    case preserveAll
}

/// A string-keyed collection that remembers the order its keys arrived in.
///
/// JSON and YAML objects are unordered by specification, but discarding the source order makes
/// re-serialization and diffs churn for no reason, so the order is kept and written back out.
/// It carries no meaning beyond that: two objects with the same pairs in different orders are
/// equal, and hashing agrees.
///
/// Keys are not required to be unique — what a parser stores depends on its ``DuplicateKeyPolicy``,
/// and both the YAML parser and the tolerant JSON scanner always keep every occurrence. When they
/// repeat, the two ways of reading a key disagree: a subscript returns the first occurrence, while
/// decoding into a `Decodable` type resolves the last one. Resolve duplicates at parse time if
/// that difference would reach anyone.
public struct OrderedObject: Sendable, Hashable {
    public private(set) var entries: [(key: String, value: StructuredValue)]

    public init() { entries = [] }

    public init(_ entries: [(key: String, value: StructuredValue)]) {
        self.entries = entries
    }

    /// Builds an object from a Swift dictionary, in whatever order the dictionary iterates.
    ///
    /// That order is arbitrary and varies between runs. Use the entries initializer when the
    /// output order has to be stable.
    public init(_ dictionary: [String: StructuredValue]) {
        self.entries = dictionary.map { ($0.key, $0.value) }
    }

    public var keys: [String] { entries.map(\.key) }
    public var count: Int { entries.count }
    public var isEmpty: Bool { entries.isEmpty }

    public subscript(key: String) -> StructuredValue? {
        get { entries.first { $0.key == key }?.value }
        set {
            if let newValue {
                if let index = entries.firstIndex(where: { $0.key == key }) {
                    entries[index].value = newValue
                } else {
                    entries.append((key, newValue))
                }
            } else {
                entries.removeAll { $0.key == key }
            }
        }
    }

    public mutating func append(key: String, value: StructuredValue) {
        entries.append((key, value))
    }

    /// Removes the first entry with this key and returns its value, leaving any later duplicates in place.
    @discardableResult
    public mutating func removeValue(forKey key: String) -> StructuredValue? {
        guard let index = entries.firstIndex(where: { $0.key == key }) else { return nil }
        return entries.remove(at: index).value
    }

    /// A plain Swift dictionary view, which drops the ordering and collapses duplicate keys to the last one.
    public var dictionary: [String: StructuredValue] {
        Dictionary(entries.map { ($0.key, $0.value) }, uniquingKeysWith: { _, last in last })
    }

    /// Builds an object from parsed entries, resolving repeated keys as the policy dictates.
    ///
    /// Returns nil only under ``DuplicateKeyPolicy/reject`` and only when a key actually repeats;
    /// every other policy always produces an object. Under the winner-takes-one policies the
    /// surviving entry sits at the position of the first occurrence, so source order is preserved
    /// even when the value comes from a later one.
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

    /// Compares pairs, not order: two objects holding the same names and values are equal however they are arranged.
    ///
    /// Order is carried for serialization, not meaning, so it stays out of the comparison.
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
