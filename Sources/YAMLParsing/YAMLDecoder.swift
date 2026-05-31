import Foundation
import StructuredDataCore

/// YAML entry point for the consumer-facing decode contract.
///
/// Composes ``YAMLParser`` (Layer 1) with the shared decoding backbone, so YAML
/// payloads decode into `Codable` types through the same path as JSON. Inject as
/// `any StructuredDecoding` to keep call sites format-agnostic.
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
