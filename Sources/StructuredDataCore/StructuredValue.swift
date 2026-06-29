/// 全パーサが共有するフォーマット非依存の中間表現。
///
/// ライブラリの共通通貨。全フォーマットパーサが `StructuredValue` を生成し、単一の `Decoder` ブリッジが任意の `Decodable` 型へ変換する。
/// YAML タグ/アンカーや XML 属性/混在コンテンツのようにより豊かなモデルを持つフォーマットは、独自ノード型を保持したうえでこの型へ射影する。
@dynamicMemberLookup
public enum StructuredValue: Sendable, Hashable {
    case null
    case bool(Bool)
    case number(StructuredNumber)
    case string(String)
    case array([StructuredValue])
    case object(OrderedObject)
}

extension StructuredValue {
    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    public var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    public var numberValue: StructuredNumber? {
        if case .number(let value) = self { return value }
        return nil
    }

    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public var arrayValue: [StructuredValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    public var objectValue: OrderedObject? {
        if case .object(let value) = self { return value }
        return nil
    }
}

extension StructuredValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) { self = .null }
}

extension StructuredValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}

extension StructuredValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self = .number(StructuredNumber(unchecked: String(value))) }
}

extension StructuredValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) { self = .number(StructuredNumber(unchecked: String(value))) }
}

extension StructuredValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
}

extension StructuredValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: StructuredValue...) { self = .array(elements) }
}

extension StructuredValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, StructuredValue)...) {
        self = .object(OrderedObject(elements.map { ($0.0, $0.1) }))
    }
}
