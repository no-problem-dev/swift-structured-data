import Foundation

/// Factories for building values by hand, and a bridge to and from untyped Foundation graphs.
///
/// The number factories exist so a call site can write a number without naming
/// ``StructuredNumber``. There is deliberately no factory taking a `[String: StructuredValue]`:
/// ``OrderedObject`` is already `ExpressibleByDictionaryLiteral`, so such an overload would be
/// ambiguous with the object case. Write a dictionary literal or an ``OrderedObject`` instead.
extension StructuredValue {
    public static func int(_ value: some BinaryInteger) -> StructuredValue {
        .number(StructuredNumber(unchecked: String(value)))
    }

    public static func double(_ value: Double) -> StructuredValue {
        .number(StructuredNumber(unchecked: String(value)))
    }

    /// The same data as an untyped graph of Foundation types, for handing to an API that predates this one.
    ///
    /// Produces `NSNull`, `Bool`, `Int`, `Double`, `String`, `[Any]` and `[String: Any]`, the shapes
    /// `JSONSerialization` yields. This is a lossy exit: a number that is not spelled as an `Int`
    /// becomes a `Double`, so a large integer literal loses digits here even though the tree still
    /// holds them, and repeated keys collapse.
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

    /// Builds a value from an untyped Foundation graph, mapping anything unrecognised to null.
    ///
    /// Numbers come in through `NSNumber`, whose own text is used, so an already-rounded `Double`
    /// stays rounded. Boolean-valued `NSNumber` instances are distinguished from numeric ones.
    /// Note that a type this does not know becomes null rather than an error.
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
