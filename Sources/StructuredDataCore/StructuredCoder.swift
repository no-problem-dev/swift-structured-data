import Foundation

extension StructuredValue {
    /// Decodes this subtree into a concrete type, reporting a mismatch instead of swallowing it.
    ///
    /// This is the strict counterpart to the exploratory accessors: where those give nil for
    /// anything unexpected, this throws a `DecodingError` naming the coding path.
    public func decode<T: Decodable>(_ type: T.Type, options: DecodingOptions = .init()) throws -> T {
        try decodeScalar(type, options: options, codingPath: [])
    }

    /// Builds a tree from any encodable value, without going through a serialized form.
    public static func encoded<T: Encodable>(_ value: T, options: EncodingOptions = .init()) throws -> StructuredValue {
        try options.lower(value, codingPath: [])
    }
}

/// Pairs any parser with the shared decoding backbone to get a full decoder.
///
/// This is how a format target exposes a decoder without reimplementing `Decoder` machinery:
/// supply a parser, and parsing and decoding compose into one type. ``parse(_:)`` remains
/// available for the times you want the tree rather than a Swift type.
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

/// Pairs any serializer with the shared encoding backbone to get a full encoder.
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
