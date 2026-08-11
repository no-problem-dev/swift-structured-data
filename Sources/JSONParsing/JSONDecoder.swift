import Foundation
import StructuredDataCore

/// Decodes JSON straight into a Swift type, composing the parser with the shared decoding backbone.
///
/// Inject it as `any StructuredDecoding` to keep a call site from naming its format at all.
/// ``value(from:)`` is the escape hatch when you want the parsed tree rather than a Swift type.
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

/// Encodes a Swift value as JSON, composing the shared encoding backbone with the serializer.
public struct JSONEncoder: StructuredEncoding {
    public var encodingOptions: EncodingOptions
    public var serializerOptions: JSONSerializer.Options

    public init(encodingOptions: EncodingOptions = .init(), serializerOptions: JSONSerializer.Options = .init()) {
        self.encodingOptions = encodingOptions
        self.serializerOptions = serializerOptions
    }

    public func value<T: Encodable>(_ value: T) throws -> StructuredValue {
        try StructuredValue.encoded(value, options: encodingOptions)
    }

    public func encode<T: Encodable>(_ value: T) throws -> Data {
        try JSONSerializer(options: serializerOptions).serialize(self.value(value))
    }

    public func string<T: Encodable>(from value: T) throws -> String {
        try JSONSerializer(options: serializerOptions).string(from: self.value(value))
    }
}
