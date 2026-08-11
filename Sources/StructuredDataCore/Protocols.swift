import Foundation

/// Reads raw bytes into the shared tree, doing no conversion to Swift types.
///
/// One conformance per format. The contract is lossless parsing measured against that format's
/// own conformance suite, which is why numbers stay as text at this stage.
public protocol DataParser: Sendable {
    func parse(_ data: Data) throws -> StructuredValue
}

/// Writes the shared tree back out as bytes.
public protocol DataSerializer: Sendable {
    func serialize(_ value: StructuredValue) throws -> Data
}

/// Decoding with the format left out, so a call site can be handed one without naming it.
///
/// Depend on this and take the concrete decoder by injection; a library then needs no import of
/// any format target. Input is fixed to `Data` rather than made generic so the protocol can be
/// used as an `any` existential.
public protocol StructuredDecoding: Sendable {
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T
}

/// Encoding with the format left out, the counterpart used the same way.
public protocol StructuredEncoding: Sendable {
    func encode<T: Encodable>(_ value: T) throws -> Data
}
