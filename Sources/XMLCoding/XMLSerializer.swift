import Foundation

/// Serializes an ``XMLElement`` tree to text, escaping content correctly.
///
/// Text escapes `&`, `<`, `>`; attribute values additionally escape `"`. This is
/// the escaping the hand-rolled prompt builders were missing.
public struct XMLSerializer: Sendable {
    public struct Options: Sendable {
        public var prettyPrinted: Bool
        public var indent: String

        public init(prettyPrinted: Bool = true, indent: String = "  ") {
            self.prettyPrinted = prettyPrinted
            self.indent = indent
        }
    }

    public var options: Options

    public init(options: Options = .init()) {
        self.options = options
    }

    public func string(from element: XMLElement) -> String {
        var output = ""
        write(element, depth: 0, into: &output)
        return output
    }

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

    /// Escapes `&`, `<`, and `>` so `text` is safe in XML element content.
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

    /// Escapes `&`, `<`, `>`, and `"` so `text` is safe in a double-quoted XML attribute value.
    public static func escapeAttribute(_ text: String) -> String {
        var result = escapeText(text)
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        return result
    }
}
