import Foundation

/// Construction and Foundation-bridging helpers.
///
/// The `int`/`double` factories let call sites build numbers without spelling
/// out `StructuredNumber`, and ``anyValue`` bridges to the JSONSerialization-style
/// `Any` graph for interop with existing APIs.
///
/// There is deliberately no `object([String:_])` factory: it would be ambiguous
/// with the `object(OrderedObject)` case, since `OrderedObject` is itself
/// `ExpressibleByDictionaryLiteral`. Use a dictionary literal or `OrderedObject`.
extension StructuredValue {
    public static func int(_ value: some BinaryInteger) -> StructuredValue {
        .number(StructuredNumber(unchecked: String(value)))
    }

    public static func double(_ value: Double) -> StructuredValue {
        .number(StructuredNumber(unchecked: String(value)))
    }

    /// A JSONSerialization-compatible `Any` representation
    /// (`NSNull`/`Bool`/`Int`/`Double`/`String`/`[Any]`/`[String: Any]`).
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

    /// Builds a value from a JSONSerialization-style `Any` graph.
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
