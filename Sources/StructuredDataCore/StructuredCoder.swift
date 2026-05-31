import Foundation

extension StructuredValue {
    /// Decodes this value into a concrete `Decodable` type via the shared backbone.
    public func decode<T: Decodable>(_ type: T.Type, options: DecodingOptions = .init()) throws -> T {
        try decodeScalar(type, options: options, codingPath: [])
    }

    /// Builds a value from any `Encodable`.
    public static func encoding<T: Encodable>(_ value: T, options: EncodingOptions = .init()) throws -> StructuredValue {
        try options.lower(value, codingPath: [])
    }
}

/// Adapts a ``DataParser`` into the consumer-facing ``StructuredDecoding`` contract.
///
/// Format targets expose a thin decoder built on this, so the parse step
/// (Layer 1) and the decode step (Layer 2) compose without re-implementing the
/// `Decoder` machinery per format.
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

/// Adapts a ``DataSerializer`` into the consumer-facing ``StructuredEncoding`` contract.
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
