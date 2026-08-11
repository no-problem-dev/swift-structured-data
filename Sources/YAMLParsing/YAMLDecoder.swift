import Foundation
import StructuredDataCore

/// Decodes YAML into a Swift type through exactly the same path JSON takes.
///
/// Composes the parser with the shared decoding backbone, so key strategies, date strategies and
/// error reporting behave identically across the two formats. Inject it as `any StructuredDecoding`
/// to keep a call site from naming its format. Only the first document of a stream is read.
public struct YAMLDecoder: StructuredDecoding {
    public var decodingOptions: DecodingOptions

    public init(decodingOptions: DecodingOptions = .init()) {
        self.decodingOptions = decodingOptions
    }

    public func value(from data: Data) throws -> StructuredValue {
        try YAMLParser().parse(data)
    }

    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try value(from: data).decode(type, options: decodingOptions)
    }

    public func decode<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
        try decode(type, from: Data(string.utf8))
    }
}
