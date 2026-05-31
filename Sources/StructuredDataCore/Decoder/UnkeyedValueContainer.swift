struct UnkeyedValueContainer: UnkeyedDecodingContainer {
    let options: DecodingOptions
    let codingPath: [CodingKey]
    private let array: [StructuredValue]
    private(set) var currentIndex = 0

    init(array: [StructuredValue], options: DecodingOptions, codingPath: [CodingKey]) {
        self.array = array
        self.options = options
        self.codingPath = codingPath
    }

    var count: Int? { array.count }
    var isAtEnd: Bool { currentIndex >= array.count }

    mutating func decodeNil() throws -> Bool {
        guard !isAtEnd else { throw endOfContainer() }
        if array[currentIndex].isNull {
            currentIndex += 1
            return true
        }
        return false
    }

    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let value = try next()
        return try value.decodeScalar(type, options: options, codingPath: codingPath + [IndexKey(currentIndex - 1)])
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy type: NestedKey.Type
    ) throws -> KeyedDecodingContainer<NestedKey> {
        let value = try next()
        guard case .object(let object) = value else { throw mismatch("an object", found: value) }
        return KeyedDecodingContainer(
            KeyedValueContainer<NestedKey>(object: object, options: options, codingPath: codingPath + [IndexKey(currentIndex - 1)])
        )
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        let value = try next()
        guard case .array(let inner) = value else { throw mismatch("an array", found: value) }
        return UnkeyedValueContainer(array: inner, options: options, codingPath: codingPath + [IndexKey(currentIndex - 1)])
    }

    mutating func superDecoder() throws -> Decoder {
        let value = try next()
        return ValueDecoder(value: value, options: options, codingPath: codingPath + [IndexKey(currentIndex - 1)])
    }

    private mutating func next() throws -> StructuredValue {
        guard !isAtEnd else { throw endOfContainer() }
        defer { currentIndex += 1 }
        return array[currentIndex]
    }

    private func endOfContainer() -> DecodingError {
        DecodingError.valueNotFound(
            StructuredValue.self,
            .init(codingPath: codingPath, debugDescription: "Unkeyed container is at end.")
        )
    }

    private func mismatch(_ expected: String, found: StructuredValue) -> DecodingError {
        DecodingError.typeMismatch(
            StructuredValue.self,
            .init(codingPath: codingPath, debugDescription: "Expected \(expected) but found \(found.diagnosticTypeName).")
        )
    }
}

struct IndexKey: CodingKey {
    let index: Int
    init(_ index: Int) { self.index = index }
    var intValue: Int? { index }
    var stringValue: String { "Index \(index)" }
    init?(intValue: Int) { self.index = intValue }
    init?(stringValue: String) { return nil }
}
