import Foundation
/// The decoder that turns a parsed tree into a static Swift type.
///
/// This is the whole dynamic-to-static conversion, and every format shares this one implementation:
/// a format target only has to produce a ``StructuredValue`` to get full `Codable` support, nested
/// containers and `DecodingError` reporting without writing any of it.
struct ValueDecoder: Decoder {
    let value: StructuredValue
    let options: DecodingOptions
    let codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { [:] }

    init(value: StructuredValue, options: DecodingOptions, codingPath: [CodingKey] = []) {
        self.value = value
        self.options = options
        self.codingPath = codingPath
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard case .object(let object) = value else {
            throw typeMismatch([String: StructuredValue].self)
        }
        return KeyedDecodingContainer(
            KeyedValueContainer(object: object, options: options, codingPath: codingPath)
        )
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard case .array(let array) = value else {
            throw typeMismatch([StructuredValue].self)
        }
        return UnkeyedValueContainer(array: array, options: options, codingPath: codingPath)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        SingleValueContainer(value: value, options: options, codingPath: codingPath)
    }

    private func typeMismatch(_ expected: Any.Type) -> DecodingError {
        DecodingError.typeMismatch(
            expected,
            DecodingError.Context(codingPath: codingPath, debugDescription: "Expected \(expected) but found \(value.diagnosticTypeName).")
        )
    }
}

extension StructuredValue {
    var diagnosticTypeName: String {
        switch self {
        case .null: return "null"
        case .bool: return "a boolean"
        case .number: return "a number"
        case .string: return "a string"
        case .array: return "an array"
        case .object: return "an object"
        }
    }

    /// Decodes into any decodable type, short-circuiting the two that must not go through the generic path.
    ///
    /// Asking for a ``StructuredValue`` hands back the subtree as it stands, and `Date` is
    /// intercepted when the strategy replaces its stock `Codable` conformance. Everything else
    /// recurses through the normal containers.
    func decodeScalar<T>(_ type: T.Type, options: DecodingOptions, codingPath: [CodingKey]) throws -> T where T: Decodable {
        if type == StructuredValue.self {
            return self as! T
        }
        if type == Date.self, options.dateStrategy.interceptsDate {
            return try options.dateStrategy.decode(self) as! T
        }
        return try T(from: ValueDecoder(value: self, options: options, codingPath: codingPath))
    }
}
