struct SingleValueContainer: SingleValueDecodingContainer {
    let value: StructuredValue
    let options: DecodingOptions
    let codingPath: [CodingKey]

    func decodeNil() -> Bool { value.isNull }

    func decode(_ type: Bool.Type) throws -> Bool {
        guard case .bool(let bool) = value else { throw mismatch(type) }
        return bool
    }

    func decode(_ type: String.Type) throws -> String {
        guard case .string(let string) = value else { throw mismatch(type) }
        return string
    }

    func decode(_ type: Double.Type) throws -> Double { try floating(type) { $0.double } }
    func decode(_ type: Float.Type) throws -> Float { try floating(type) { Float($0.double) } }

    func decode(_ type: Int.Type) throws -> Int { try integer(type) }
    func decode(_ type: Int8.Type) throws -> Int8 { try integer(type) }
    func decode(_ type: Int16.Type) throws -> Int16 { try integer(type) }
    func decode(_ type: Int32.Type) throws -> Int32 { try integer(type) }
    func decode(_ type: Int64.Type) throws -> Int64 { try integer(type) }
    func decode(_ type: UInt.Type) throws -> UInt { try integer(type) }
    func decode(_ type: UInt8.Type) throws -> UInt8 { try integer(type) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { try integer(type) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { try integer(type) }
    func decode(_ type: UInt64.Type) throws -> UInt64 { try integer(type) }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try value.decodeScalar(type, options: options, codingPath: codingPath)
    }

    private func integer<T: FixedWidthInteger>(_ type: T.Type) throws -> T {
        guard case .number(let number) = value else { throw mismatch(type) }
        guard let result = T(number.text) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: codingPath, debugDescription: "Number \(number.text) does not fit in \(type).")
            )
        }
        return result
    }

    private func floating<T>(_ type: T.Type, _ convert: (StructuredNumber) -> T) throws -> T {
        guard case .number(let number) = value else { throw mismatch(type) }
        return convert(number)
    }

    private func mismatch(_ expected: Any.Type) -> DecodingError {
        DecodingError.typeMismatch(
            expected,
            .init(codingPath: codingPath, debugDescription: "Expected \(expected) but found \(value.diagnosticTypeName).")
        )
    }
}
