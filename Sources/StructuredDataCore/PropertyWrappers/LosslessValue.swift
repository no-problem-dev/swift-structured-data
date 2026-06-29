/// API が異なるプリミティブ型で返す可能性のある値をデコードするプロパティラッパー。
///
/// 例: 文字列 `"42"` として届く数値や `"true"` として届く Bool。
/// 型が一致しない場合は文字列経由のラウンドトリップで再試行するため、上流の型付けの揺れでデコードが壊れない。
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
