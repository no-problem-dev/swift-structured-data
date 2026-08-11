/// Reads one value as a concrete Swift type, converting numbers from their text and never coercing across types.
///
/// Integers are read from the stored digits rather than through `Double`, so precision cannot be
/// lost on the way in — but the reading is exact in both directions. A number spelled `1.5`, `1e2`
/// or `42.0` yields no integer at all, and neither does one outside the target type's range or a
/// negative one requested as unsigned; every such case throws `dataCorrupted`, naming the number
/// and the type. Only ``StructuredValue/int(_:)`` and ``StructuredNumber/coercedInt`` truncate.
///
/// Floating-point reads fail on the same terms. A magnitude past the target type's range has no
/// nearest representable value, so `1e400` as a `Double` and `1e300` as a `Float` throw
/// `dataCorrupted` rather than arriving as infinity. Rounding is a different matter and still
/// happens quietly: `0.1` is not exactly representable, `1e-400` reads as zero, and everything
/// past 17 significant digits is gone — in each case the value returned is the nearest one there
/// is, which is what asking for a `Double` means.
///
/// Nothing else converts: a string is not read as a number, and a number is not read as a string.
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

    func decode(_ type: Double.Type) throws -> Double { try floating(type) { $0.exactDouble } }
    func decode(_ type: Float.Type) throws -> Float { try floating(type) { $0.exactFloat } }

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

    private func floating<T>(_ type: T.Type, _ convert: (StructuredNumber) -> T?) throws -> T {
        guard case .number(let number) = value else { throw mismatch(type) }
        guard let result = convert(number) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: codingPath, debugDescription: "Number \(number.text) does not fit in \(type).")
            )
        }
        return result
    }

    private func mismatch(_ expected: Any.Type) -> DecodingError {
        DecodingError.typeMismatch(
            expected,
            .init(codingPath: codingPath, debugDescription: "Expected \(expected) but found \(value.diagnosticTypeName).")
        )
    }
}
