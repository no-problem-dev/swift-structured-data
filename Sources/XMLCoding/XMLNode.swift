/// An XML element with ordered attributes and ordered children.
///
/// Order and the attribute/child distinction are preserved because XML, unlike
/// JSON, gives both significance.
public struct XMLElement: Sendable, Equatable {
    public var name: String
    public var attributes: [XMLAttribute]
    public var children: [XMLNode]

    public init(name: String, attributes: [XMLAttribute] = [], children: [XMLNode] = []) {
        self.name = name
        self.attributes = attributes
        self.children = children
    }

    /// The concatenated text of direct text/CDATA children.
    public var text: String {
        children.reduce(into: "") { result, node in
            switch node {
            case .text(let value), .cdata(let value): result += value
            default: break
            }
        }
    }

    public var elements: [XMLElement] {
        children.compactMap { if case .element(let element) = $0 { return element } else { return nil } }
    }

    public func attribute(_ name: String) -> String? {
        attributes.first { $0.name == name }?.value
    }

    public func firstElement(named name: String) -> XMLElement? {
        elements.first { $0.name == name }
    }
}

public enum XMLNode: Sendable, Equatable {
    case element(XMLElement)
    case text(String)
    case cdata(String)
    case comment(String)
}

public struct XMLAttribute: Sendable, Equatable {
    public var name: String
    public var value: String

    public init(_ name: String, _ value: String) {
        self.name = name
        self.value = value
    }
}
