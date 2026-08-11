/// The format-independent tree that every parser here produces and every decoder here consumes.
///
/// This is the library's common currency. Each format parser builds one of these, and a single
/// `Decoder` bridge turns it into any `Decodable` type, so adding a format costs a parser and no
/// `Codable` machinery. Numbers ride as ``StructuredNumber`` rather than `Double`, so a document
/// can go in and come back out without silent rounding.
///
/// A format whose model is richer than this keeps its own node type instead of lowering into it.
/// XML is the case in point: attributes, comments, CDATA and mixed content have no counterpart
/// among these cases, so `XMLCoding` parses to `XMLElement` and stays there — there is no bridge
/// from an XML tree to this type, and consequently no XML `Codable` support.
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
