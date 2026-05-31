struct KeyedValueContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let options: DecodingOptions
    let codingPath: [CodingKey]
    private let lookup: [String: StructuredValue]
    private let orderedKeys: [String]

    init(object: OrderedObject, options: DecodingOptions, codingPath: [CodingKey]) {
        self.options = options
        self.codingPath = codingPath
        var lookup: [String: StructuredValue] = [:]
        var orderedKeys: [String] = []
        for entry in object.entries {
            let mapped = options.keyStrategy.convert(entry.key)
            if lookup[mapped] == nil { orderedKeys.append(mapped) }
            lookup[mapped] = entry.value
        }
        self.lookup = lookup
        self.orderedKeys = orderedKeys
    }

    var allKeys: [Key] { orderedKeys.compactMap { Key(stringValue: $0) } }

    func contains(_ key: Key) -> Bool { lookup[key.stringValue] != nil }

    func decodeNil(forKey key: Key) throws -> Bool {
        try required(key).isNull
    }

    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        try required(key).decodeScalar(type, options: options, codingPath: codingPath + [key])
    }

    func nestedContainer<NestedKey: CodingKey>(
        keyedBy type: NestedKey.Type, forKey key: Key
    ) throws -> KeyedDecodingContainer<NestedKey> {
        let nested = try required(key)
        guard case .object(let object) = nested else { throw mismatch(key, expected: "an object", found: nested) }
        return KeyedDecodingContainer(
            KeyedValueContainer<NestedKey>(object: object, options: options, codingPath: codingPath + [key])
        )
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        let nested = try required(key)
        guard case .array(let array) = nested else { throw mismatch(key, expected: "an array", found: nested) }
        return UnkeyedValueContainer(array: array, options: options, codingPath: codingPath + [key])
    }

    func superDecoder() throws -> Decoder {
        ValueDecoder(value: lookup["super"] ?? .null, options: options, codingPath: codingPath)
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        ValueDecoder(value: lookup[key.stringValue] ?? .null, options: options, codingPath: codingPath + [key])
    }

    private func required(_ key: Key) throws -> StructuredValue {
        guard let value = lookup[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key, .init(codingPath: codingPath, debugDescription: "No value associated with key \(key.stringValue).")
            )
        }
        return value
    }

    private func mismatch(_ key: Key, expected: String, found: StructuredValue) -> DecodingError {
        DecodingError.typeMismatch(
            StructuredValue.self,
            .init(codingPath: codingPath + [key], debugDescription: "Expected \(expected) but found \(found.diagnosticTypeName).")
        )
    }
}
