/// `Codable` 準拠により、`StructuredValue` を他の Codable 型に埋め込み Foundation を含む任意のエンコーダ/デコーダでラウンドトリップできる。
/// ライブラリ独自パーサは数値精度を保持するが、このパスはホストのコーダーが対応する範囲に従う。
extension StructuredValue: Codable {
    public init(from decoder: Decoder) throws {
        if var unkeyed = try? decoder.unkeyedContainer() {
            var elements: [StructuredValue] = []
            if let count = unkeyed.count { elements.reserveCapacity(count) }
            while !unkeyed.isAtEnd {
                elements.append(try unkeyed.decode(StructuredValue.self))
            }
            self = .array(elements)
            return
        }
        if let keyed = try? decoder.container(keyedBy: DynamicCodingKey.self) {
            var entries: [(key: String, value: StructuredValue)] = []
            for key in keyed.allKeys {
                entries.append((key.stringValue, try keyed.decode(StructuredValue.self, forKey: key)))
            }
            self = .object(OrderedObject(entries))
            return
        }
        let single = try decoder.singleValueContainer()
        if single.decodeNil() { self = .null; return }
        if let bool = try? single.decode(Bool.self) { self = .bool(bool); return }
        if let int = try? single.decode(Int64.self) { self = .number(StructuredNumber(unchecked: String(int))); return }
        if let uint = try? single.decode(UInt64.self) { self = .number(StructuredNumber(unchecked: String(uint))); return }
        if let double = try? single.decode(Double.self) { self = .number(StructuredNumber(unchecked: String(double))); return }
        if let string = try? single.decode(String.self) { self = .string(string); return }
        throw DecodingError.dataCorrupted(
            .init(codingPath: decoder.codingPath, debugDescription: "Unsupported value for StructuredValue.")
        )
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        case .bool(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .number(let number):
            var container = encoder.singleValueContainer()
            if let int = number.int64 { try container.encode(int) }
            else if let uint = number.uint64 { try container.encode(uint) }
            else { try container.encode(number.double) }
        case .string(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .array(let elements):
            var container = encoder.unkeyedContainer()
            for element in elements { try container.encode(element) }
        case .object(let object):
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            for entry in object.entries {
                try container.encode(entry.value, forKey: DynamicCodingKey(entry.key))
            }
        }
    }
}

struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
