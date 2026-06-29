import Foundation
import StructuredDataCore

/// 消費者向けデコードプロトコルへの JSON エントリポイント。
///
/// ``JSONParser``（Layer 1）と共有デコードバックボーン（Layer 2）の薄い合成体。
/// `any StructuredDecoding` として注入することでコールサイトをフォーマット非依存に保てる。
public struct JSONDecoder: StructuredDecoding {
    public var parsingOptions: JSONParsingOptions
    public var decodingOptions: DecodingOptions

    public init(parsingOptions: JSONParsingOptions = .init(), decodingOptions: DecodingOptions = .init()) {
        self.parsingOptions = parsingOptions
        self.decodingOptions = decodingOptions
    }

    public func value(from data: Data) throws -> StructuredValue {
        try JSONParser(options: parsingOptions).parse(data)
    }

    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try value(from: data).decode(type, options: decodingOptions)
    }

    public func decode<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
        try decode(type, from: Data(string.utf8))
    }
}

/// 消費者向けエンコードプロトコルへの JSON エントリポイント。
public struct JSONEncoder: StructuredEncoding {
    public var encodingOptions: EncodingOptions
    public var serializerOptions: JSONSerializer.Options

    public init(encodingOptions: EncodingOptions = .init(), serializerOptions: JSONSerializer.Options = .init()) {
        self.encodingOptions = encodingOptions
        self.serializerOptions = serializerOptions
    }

    public func value<T: Encodable>(_ value: T) throws -> StructuredValue {
        try StructuredValue.encoding(value, options: encodingOptions)
    }

    public func encode<T: Encodable>(_ value: T) throws -> Data {
        try JSONSerializer(options: serializerOptions).serialize(self.value(value))
    }

    public func string<T: Encodable>(from value: T) throws -> String {
        try JSONSerializer(options: serializerOptions).string(from: self.value(value))
    }
}
