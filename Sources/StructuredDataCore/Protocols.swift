import Foundation

/// Parses raw bytes into the neutral intermediate representation.
///
/// Implemented per format (JSON, YAML, XML). This is Layer 1 — lossless parsing
/// validated against the format's official conformance suite. It performs no
/// type coercion toward user types.
public protocol DataParser: Sendable {
    func parse(_ data: Data) throws -> StructuredValue
}

/// Serializes the neutral intermediate representation back into bytes.
public protocol DataSerializer: Sendable {
    func serialize(_ value: StructuredValue) throws -> Data
}

/// The consumer-facing decode contract.
///
/// Consumers depend on this abstraction and receive a concrete decoder by
/// injection, so a library never imports a specific format target. Input is
/// fixed to `Data` to keep the protocol usable as an existential (`any`).
public protocol StructuredDecoding: Sendable {
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T
}

/// The consumer-facing encode contract.
public protocol StructuredEncoding: Sendable {
    func encode<T: Encodable>(_ value: T) throws -> Data
}
