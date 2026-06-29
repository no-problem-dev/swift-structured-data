import Foundation

/// 構築用ファクトリと Foundation ブリッジングのヘルパー。
///
/// `int`/`double` ファクトリにより、コールサイトで `StructuredNumber` を明示せずに数値を構築できる。
/// ``anyValue`` は既存 API との相互運用のために JSONSerialization スタイルの `Any` グラフへブリッジする。
///
/// `object([String:_])` ファクトリは意図的に存在しない。`OrderedObject` 自体が `ExpressibleByDictionaryLiteral` のため
/// `object(OrderedObject)` case と曖昧になる。辞書リテラルか `OrderedObject` を使うこと。
extension StructuredValue {
    public static func int(_ value: some BinaryInteger) -> StructuredValue {
        .number(StructuredNumber(unchecked: String(value)))
    }

    public static func double(_ value: Double) -> StructuredValue {
        .number(StructuredNumber(unchecked: String(value)))
    }

    /// JSONSerialization 互換の `Any` 表現（`NSNull`/`Bool`/`Int`/`Double`/`String`/`[Any]`/`[String: Any]`）。
    public var anyValue: Any {
        switch self {
        case .null: return NSNull()
        case .bool(let value): return value
        case .number(let number): return number.int ?? number.double
        case .string(let value): return value
        case .array(let array): return array.map(\.anyValue)
        case .object(let object):
            return object.entries.reduce(into: [String: Any]()) { $0[$1.key] = $1.value.anyValue }
        }
    }

    /// JSONSerialization スタイルの `Any` グラフから値を構築する。
    public init(anyValue: Any) {
        if anyValue is NSNull { self = .null; return }
        if let number = anyValue as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() { self = .bool(number.boolValue); return }
            self = .number(StructuredNumber(unchecked: number.stringValue)); return
        }
        switch anyValue {
        case let value as Bool: self = .bool(value)
        case let value as String: self = .string(value)
        case let value as [Any]: self = .array(value.map(StructuredValue.init(anyValue:)))
        case let value as [String: Any]:
            self = .object(OrderedObject(value.map { ($0.key, StructuredValue(anyValue: $0.value)) }))
        default: self = .null
        }
    }
}
