/// Decodes a value that an API may deliver under a different primitive type,
/// e.g. a number arriving as the string `"42"` or a bool as `"true"`.
///
/// On a type mismatch it retries through a string round-trip before giving up,
/// so flaky upstream typing does not break decoding.
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
