/// Reads a field whose primitive type the producer is inconsistent about, such as a number quoted as a string.
///
/// Four attempts, in order, and the first that yields a value wins:
///
/// 1. Decode the target type directly.
/// 2. Decode a string and reconstruct the value from it — this is the case that recovers `"42"`.
/// 3. Decode a `Double` and reconstruct from its text.
/// 4. Decode a `Bool` and reconstruct from `"true"` or `"false"`.
///
/// If all four fail it throws, so unlike the defaulting wrapper nothing is silently substituted.
///
/// Reconstruction always goes through text, which decides what the numeric steps can and cannot
/// do. An integer field recovers `"42"` but not `42.0`, because the double's text is `"42.0"` and
/// no integer parses from that — this widens the accepted spellings, it does not round or truncate.
@propertyWrapper
public struct LosslessValue<Value: LosslessStringConvertible & Codable & Sendable>: Codable, Sendable {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let direct = try? container.decode(Value.self) {
            wrappedValue = direct
            return
        }
        if let string = try? container.decode(String.self), let recovered = Value(string) {
            wrappedValue = recovered
            return
        }
        if let number = try? container.decode(Double.self), let recovered = Value(String(number)) {
            wrappedValue = recovered
            return
        }
        if let flag = try? container.decode(Bool.self), let recovered = Value(String(flag)) {
            wrappedValue = recovered
            return
        }
        throw DecodingError.dataCorrupted(
            .init(codingPath: decoder.codingPath, debugDescription: "Cannot losslessly decode \(Value.self).")
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

extension LosslessValue: Equatable where Value: Equatable {}
extension LosslessValue: Hashable where Value: Hashable {}
