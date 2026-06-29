import Foundation

extension StructuredValue {
    /// 共有バックボーンを経由してこの値を具体的な `Decodable` 型へデコードする。
    public func decode<T: Decodable>(_ type: T.Type, options: DecodingOptions = .init()) throws -> T {
        try decodeScalar(type, options: options, codingPath: [])
    }

    /// 任意の `Encodable` から値を構築する。
    public static func encoding<T: Encodable>(_ value: T, options: EncodingOptions = .init()) throws -> StructuredValue {
        try options.lower(value, codingPath: [])
    }
}

/// ``DataParser`` を消費者向け ``StructuredDecoding`` プロトコルへ適合させるアダプター。
///
/// フォーマットターゲットはこの上に薄いデコーダを公開する。解析ステップ（Layer 1）とデコードステップ（Layer 2）が、
/// フォーマットごとに `Decoder` 機構を再実装することなく合成される。
public struct StructuredDecoder<Parser: DataParser>: StructuredDecoding {
    public let parser: Parser
    public var options: DecodingOptions

    public init(parser: Parser, options: DecodingOptions = .init()) {
        self.parser = parser
        self.options = options
    }

    public func parse(_ data: Data) throws -> StructuredValue {
        try parser.parse(data)
    }

    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try parser.parse(data).decodeScalar(type, options: options, codingPath: [])
    }
}

/// ``DataSerializer`` を消費者向け ``StructuredEncoding`` プロトコルへ適合させるアダプター。
public struct StructuredEncoder<Serializer: DataSerializer>: StructuredEncoding {
    public let serializer: Serializer
    public var options: EncodingOptions

    public init(serializer: Serializer, options: EncodingOptions = .init()) {
        self.serializer = serializer
        self.options = options
    }

    public func encode<T: Encodable>(_ value: T) throws -> Data {
        try serializer.serialize(options.lower(value, codingPath: []))
    }
}
