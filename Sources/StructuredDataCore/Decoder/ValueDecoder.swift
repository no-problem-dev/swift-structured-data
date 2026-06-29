import Foundation
/// `StructuredValue` をソースとする `Decoder`。
///
/// 全 `Decodable` に対して「動的な値→静的な型」変換を実現するバックボーン。
/// 全フォーマットがこの 1 実装を再利用するため、フォーマットターゲットは `StructuredValue` を生成するだけで
/// `Codable` 完全対応・ネストされたコンテナ・`DecodingError` 報告を無償で得られる。
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

    /// この表現に保持された値を具体的なプリミティブまたは `Decodable` 型へデコードする。
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
