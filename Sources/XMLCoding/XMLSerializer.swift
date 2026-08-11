import Foundation

/// Writes an element tree back out as text, escaping content so that interpolated values cannot break the markup.
///
/// Escaping is the point: hand-rolled prompt builders routinely concatenate user text into tags and
/// produce a document that no longer parses, or that closes a tag the caller never intended.
/// Element text escapes `&`, `<` and `>`; attribute values escape those and `"`.
///
/// Two things pass through unescaped, because escaping them would change their meaning: CDATA
/// content and comment text. A value containing `]]>` or `--` therefore still needs care.
/// An element with no children is written in the self-closing form, so an empty pair of tags in
/// the source does not survive verbatim.
public struct XMLSerializer: Sendable {
    public struct Options: Sendable {
        /// Whether to break lines and indent, which is on by default here.
        ///
        /// Only elements whose children include another element are broken across lines; an
        /// element holding just text stays inline, so pretty printing never inserts whitespace
        /// into content.
        public var prettyPrinted: Bool
        /// The indent added per nesting level when pretty printing.
        public var indent: String

        /// - Parameters:
        ///   - prettyPrinted: Whether to break lines and indent. Defaults to true.
        ///   - indent: The indent per level. Defaults to two spaces.
        public init(prettyPrinted: Bool = true, indent: String = "  ") {
            self.prettyPrinted = prettyPrinted
            self.indent = indent
        }
    }

    public var options: Options

    public init(options: Options = .init()) {
        self.options = options
    }

    /// Serializes a tree to text, with no XML declaration written.
    ///
    /// - Parameter element: The root element.
    public func string(from element: XMLElement) -> String {
        var output = ""
        write(element, depth: 0, into: &output)
        return output
    }

    /// Serializes a tree to UTF-8 bytes.
    ///
    /// - Parameter element: The root element.
    public func data(from element: XMLElement) -> Data {
        Data(string(from: element).utf8)
    }

    private func write(_ element: XMLElement, depth: Int, into output: inout String) {
        output += "<" + element.name
        for attribute in element.attributes {
            output += " \(attribute.name)=\"\(Self.escapeAttribute(attribute.value))\""
        }
        if element.children.isEmpty {
            output += " />"
            return
        }
        output += ">"

        let onlyText = element.children.allSatisfy { if case .element = $0 { return false } else { return true } }
        if onlyText || !options.prettyPrinted {
            for child in element.children { writeChild(child, depth: depth, inline: true, into: &output) }
        } else {
            for child in element.children {
                newline(depth + 1, into: &output)
                writeChild(child, depth: depth + 1, inline: false, into: &output)
            }
            newline(depth, into: &output)
        }
        output += "</\(element.name)>"
    }

    private func writeChild(_ child: XMLNode, depth: Int, inline: Bool, into output: inout String) {
        switch child {
        case .element(let element): write(element, depth: depth, into: &output)
        case .text(let value): output += Self.escapeText(value)
        case .cdata(let value): output += "<![CDATA[\(value)]]>"
        case .comment(let value): output += "<!--\(value)-->"
        }
    }

    private func newline(_ depth: Int, into output: inout String) {
        guard options.prettyPrinted else { return }
        output += "\n" + String(repeating: options.indent, count: depth)
    }

    /// Escapes the three characters that would otherwise be read as markup inside element content.
    ///
    /// Quotes are left alone, since they carry no meaning between tags. Use ``escapeAttribute(_:)``
    /// for anything going inside a quoted attribute value.
    public static func escapeText(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            default: result.append(character)
            }
        }
        return result
    }

    /// Escapes markup characters plus the double quote, for a value going inside double quotes.
    ///
    /// A single quote is not escaped, so this output is only safe within double-quoted attributes.
    public static func escapeAttribute(_ text: String) -> String {
        var result = escapeText(text)
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        return result
    }
}
