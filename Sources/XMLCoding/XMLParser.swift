import Foundation
import StructuredDataCore

/// Parses a well-formed XML document into an ``XMLElement`` tree.
///
/// Covers elements, attributes, text, CDATA, comments, processing
/// instructions, and predefined/numeric entity references. DTD validation and
/// namespace resolution are out of scope (prefixes are kept verbatim).
public struct XMLDocumentParser: Sendable {
    public init() {}

    public func parse(_ data: Data) throws -> XMLElement {
        guard let text = String(data: data, encoding: .utf8) else { throw ParseError(.invalidUTF8) }
        return try parse(text)
    }

    public func parse(_ string: String) throws -> XMLElement {
        var scanner = Scanner(chars: Array(string))
        return try scanner.parseDocument()
    }

    private struct Scanner {
        let chars: [Character]
        var index = 0

        mutating func parseDocument() throws -> XMLElement {
            skipProlog()
            guard peek() == "<" else { throw ParseError(.malformed("expected root element")) }
            let root = try parseElement()
            skipMisc()
            guard index >= chars.count else { throw ParseError(.trailingData) }
            return root
        }

        private mutating func parseElement() throws -> XMLElement {
            advance() // consume '<'
            let name = readName()
            guard !name.isEmpty else { throw ParseError(.malformed("expected element name")) }
            var attributes: [XMLAttribute] = []
            while true {
                skipSpace()
                guard let ch = peek() else { throw ParseError(.unexpectedEndOfInput) }
                if ch == "/" { advance(); try expect(">"); return XMLElement(name: name, attributes: attributes) }
                if ch == ">" { advance(); break }
                attributes.append(try parseAttribute())
            }
            let children = try parseChildren(until: name)
            return XMLElement(name: name, attributes: attributes, children: children)
        }

        private mutating func parseAttribute() throws -> XMLAttribute {
            let name = readName()
            guard !name.isEmpty else { throw ParseError(.malformed("expected attribute name")) }
            skipSpace()
            try expect("=")
            skipSpace()
            guard let quote = peek(), quote == "\"" || quote == "'" else {
                throw ParseError(.malformed("expected quoted attribute value"))
            }
            advance()
            var value = ""
            while let ch = peek(), ch != quote {
                if ch == "&" { value.append(try readEntity()) } else { value.append(ch); advance() }
            }
            try expect(String(quote))
            return XMLAttribute(name, value)
        }

        private mutating func parseChildren(until name: String) throws -> [XMLNode] {
            var children: [XMLNode] = []
            var text = ""
            func flushText() {
                if !text.isEmpty { children.append(.text(text)); text = "" }
            }
            while let ch = peek() {
                if ch == "<" {
                    if matches("<![CDATA[") {
                        flushText()
                        children.append(.cdata(readCDATA()))
                    } else if matches("<!--") {
                        flushText()
                        children.append(.comment(readComment()))
                    } else if matches("</") {
                        flushText()
                        advance(2)
                        let closing = readName()
                        skipSpace()
                        try expect(">")
                        guard closing == name else { throw ParseError(.malformed("mismatched closing tag </\(closing)>")) }
                        return children
                    } else if matches("<?") {
                        skipProcessingInstruction()
                    } else {
                        flushText()
                        children.append(.element(try parseElement()))
                    }
                } else if ch == "&" {
                    text.append(try readEntity())
                } else {
                    text.append(ch)
                    advance()
                }
            }
            throw ParseError(.malformed("unclosed element <\(name)>"))
        }

        // MARK: Lexing helpers

        private mutating func readName() -> String {
            var name = ""
            while let ch = peek(), !ch.isWhitespace, ch != ">", ch != "/", ch != "=", ch != "<" {
                name.append(ch)
                advance()
            }
            return name
        }

        private mutating func readEntity() throws -> Character {
            advance() // '&'
            var name = ""
            while let ch = peek(), ch != ";" { name.append(ch); advance() }
            try expect(";")
            switch name {
            case "amp": return "&"
            case "lt": return "<"
            case "gt": return ">"
            case "quot": return "\""
            case "apos": return "'"
            default:
                if name.hasPrefix("#x") || name.hasPrefix("#X"), let value = UInt32(name.dropFirst(2), radix: 16),
                   let scalar = UnicodeScalar(value) { return Character(scalar) }
                if name.hasPrefix("#"), let value = UInt32(name.dropFirst()), let scalar = UnicodeScalar(value) {
                    return Character(scalar)
                }
                throw ParseError(.malformed("unknown entity &\(name);"))
            }
        }

        private mutating func readCDATA() -> String {
            advance(9) // '<![CDATA['
            var content = ""
            while index < chars.count {
                if matches("]]>") { advance(3); break }
                content.append(chars[index]); advance()
            }
            return content
        }

        private mutating func readComment() -> String {
            advance(4) // '<!--'
            var content = ""
            while index < chars.count {
                if matches("-->") { advance(3); break }
                content.append(chars[index]); advance()
            }
            return content
        }

        private mutating func skipProcessingInstruction() {
            while index < chars.count, !matches("?>") { advance() }
            if matches("?>") { advance(2) }
        }

        private mutating func skipProlog() {
            skipMisc()
            if matches("<?xml") { skipProcessingInstruction() }
            skipMisc()
            while matches("<!") || matches("<?") {
                if matches("<!--") { _ = readComment() } else { skipProcessingInstruction() }
                skipMisc()
            }
        }

        private mutating func skipMisc() {
            while let ch = peek(), ch.isWhitespace { advance() }
        }

        private mutating func skipSpace() {
            while let ch = peek(), ch.isWhitespace { advance() }
        }

        private func matches(_ literal: String) -> Bool {
            let target = Array(literal)
            guard index + target.count <= chars.count else { return false }
            for offset in target.indices where chars[index + offset] != target[offset] { return false }
            return true
        }

        private func peek() -> Character? { index < chars.count ? chars[index] : nil }
        private mutating func advance(_ count: Int = 1) { index += count }
        private mutating func expect(_ literal: String) throws {
            for character in literal {
                guard peek() == character else { throw ParseError(.malformed("expected '\(literal)'")) }
                advance()
            }
        }
    }
}
