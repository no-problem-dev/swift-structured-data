import StructuredDataCore

/// YAML フロースタイル（`[...]`、`{...}`、クォートスカラー）を解析し、プレインフロースカラーを Core スキーマで解決する。
struct YAMLFlowScanner {
    private let chars: [Character]
    private var index: Int

    init(_ text: String) {
        self.chars = Array(text)
        self.index = 0
    }

    mutating func parseDocument() throws -> StructuredValue {
        skipSpace()
        let value = try parseNode()
        skipSpace()
        guard index >= chars.count else { throw ParseError(.trailingData) }
        return value
    }

    private mutating func parseNode() throws -> StructuredValue {
        skipSpace()
        guard let ch = peek() else { return .null }
        switch ch {
        case "[": return try parseSequence()
        case "{": return try parseMapping()
        case "\"": return .string(try parseDoubleQuoted())
        case "'": return .string(try parseSingleQuoted())
        default: return resolvePlain(readPlain(stopAt: [",", "]", "}"]))
        }
    }

    private mutating func parseSequence() throws -> StructuredValue {
        advance()
        var elements: [StructuredValue] = []
        skipSpace()
        if peek() == "]" { advance(); return .array(elements) }
        while true {
            elements.append(try parseNode())
            skipSpace()
            switch peek() {
            case ",": advance(); skipSpace(); if peek() == "]" { advance(); return .array(elements) }
            case "]": advance(); return .array(elements)
            default: throw ParseError(.malformed("expected ',' or ']' in flow sequence"))
            }
        }
    }

    private mutating func parseMapping() throws -> StructuredValue {
        advance()
        var entries: [(key: String, value: StructuredValue)] = []
        skipSpace()
        if peek() == "}" { advance(); return .object(OrderedObject(entries)) }
        while true {
            skipSpace()
            let key = try parseFlowKey()
            skipSpace()
            var value: StructuredValue = .null
            if peek() == ":" {
                advance()
                value = try parseNode()
            }
            entries.append((key, value))
            skipSpace()
            switch peek() {
            case ",": advance(); skipSpace(); if peek() == "}" { advance(); return .object(OrderedObject(entries)) }
            case "}": advance(); return .object(OrderedObject(entries))
            default: throw ParseError(.malformed("expected ',' or '}' in flow mapping"))
            }
        }
    }

    private mutating func parseFlowKey() throws -> String {
        switch peek() {
        case "\"": return try parseDoubleQuoted()
        case "'": return try parseSingleQuoted()
        default: return readPlain(stopAt: [":", ",", "}"]).trimmingCharacters(in: .whitespaces)
        }
    }

    private mutating func parseSingleQuoted() throws -> String {
        advance()
        var result = ""
        while let ch = peek() {
            if ch == "'" {
                advance()
                if peek() == "'" { result.append("'"); advance(); continue }
                return result
            }
            result.append(ch)
            advance()
        }
        throw ParseError(.unexpectedEndOfInput)
    }

    private mutating func parseDoubleQuoted() throws -> String {
        advance()
        var result = ""
        while let ch = peek() {
            if ch == "\"" { advance(); return result }
            if ch == "\\" {
                advance()
                guard let esc = peek() else { throw ParseError(.unexpectedEndOfInput) }
                switch esc {
                case "n": result.append("\n")
                case "t": result.append("\t")
                case "r": result.append("\r")
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                case "/": result.append("/")
                case "0": result.append("\u{0}")
                case "b": result.append("\u{08}")
                case "f": result.append("\u{0C}")
                case "u": result.append(try readUnicode(4))
                case "U": result.append(try readUnicode(8))
                case "x": result.append(try readUnicode(2))
                default: result.append(esc)
                }
                advance()
            } else {
                result.append(ch)
                advance()
            }
        }
        throw ParseError(.unexpectedEndOfInput)
    }

    private mutating func readUnicode(_ count: Int) throws -> Character {
        var scalar: UInt32 = 0
        for _ in 0..<count {
            advance()
            guard let ch = peek(), let digit = ch.hexDigitValue else { throw ParseError(.invalidEscape("\\u")) }
            scalar = (scalar << 4) | UInt32(digit)
        }
        guard let unicode = UnicodeScalar(scalar) else { return "\u{FFFD}" }
        return Character(unicode)
    }

    private mutating func readPlain(stopAt: Set<Character>) -> String {
        var result = ""
        while let ch = peek(), !stopAt.contains(ch) {
            result.append(ch)
            advance()
        }
        return result
    }

    private func resolvePlain(_ text: String) -> StructuredValue {
        YAMLScalarResolver.resolve(text.trimmingCharacters(in: .whitespaces))
    }

    private func peek() -> Character? { index < chars.count ? chars[index] : nil }
    private mutating func advance() { index += 1 }
    private mutating func skipSpace() {
        while let ch = peek(), ch == " " || ch == "\t" || ch == "\n" { advance() }
    }
}
