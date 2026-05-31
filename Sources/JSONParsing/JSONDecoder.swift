import Foundation
import StructuredDataCore

/// JSON entry point for the consumer-facing decode contract.
///
/// A thin composition of ``JSONParser`` (Layer 1) and the shared decoding
/// backbone (Layer 2). Inject it as `any StructuredDecoding` so call sites stay
/// format-agnostic.
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

/// JSON entry point for the consumer-facing encode contract.
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
