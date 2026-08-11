/// An element holding its attributes and its children as two separate ordered lists.
///
/// Unlike a JSON object, an XML element carries meaning in both the order of its children and the
/// distinction between an attribute and a child element, so neither is flattened away. Comparing
/// two elements compares both lists in order, attributes included.
public struct XMLElement: Sendable, Equatable {
    public var name: String
    public var attributes: [XMLAttribute]
    public var children: [XMLNode]

    public init(name: String, attributes: [XMLAttribute] = [], children: [XMLNode] = []) {
        self.name = name
        self.attributes = attributes
        self.children = children
    }

    /// The direct text and CDATA children joined together, with descendants and comments left out.
    ///
    /// Whitespace is exactly as it appeared in the source, so an indented document contributes its
    /// indentation here.
    public var text: String {
        children.reduce(into: "") { result, node in
            switch node {
            case .text(let value), .cdata(let value): result += value
            default: break
            }
        }
    }

    /// The direct child elements, in order, with text, CDATA and comments filtered out.
    public var elements: [XMLElement] {
        children.compactMap { if case .element(let element) = $0 { return element } else { return nil } }
    }

    /// The value of the first attribute with this name, matched exactly including any namespace prefix.
    public func attribute(_ name: String) -> String? {
        attributes.first { $0.name == name }?.value
    }

    /// The first direct child element with this name, matched exactly including any namespace prefix.
    public func firstElement(named name: String) -> XMLElement? {
        elements.first { $0.name == name }
    }
}

/// One thing that can appear inside an element, kept distinct rather than collapsed into text.
public enum XMLNode: Sendable, Equatable {
    case element(XMLElement)
    case text(String)
    /// Character data that was written inside a CDATA section, stored without its delimiters.
    case cdata(String)
    /// A comment's inner text, retained so that a document round-trips.
    case comment(String)
}

/// One attribute, holding the name and the value with entity references already resolved.
public struct XMLAttribute: Sendable, Equatable {
    public var name: String
    public var value: String

    public init(_ name: String, _ value: String) {
        self.name = name
        self.value = value
    }
}
