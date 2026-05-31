import Foundation
import StructuredDataCore

/// A recursive-descent RFC 8259 parser operating directly on UTF-8 bytes.
///
/// Layer 1 only: it validates structure and preserves numbers as text. No
/// coercion toward user types happens here. Behaviour is pinned by the
/// `nst/JSONTestSuite` corpus (`y_` accepted, `n_` rejected).
struct JSONScanner {
    private let bytes: [UInt8]
    private var index: Int
    private let options: JSONParsingOptions

    init(bytes: [UInt8], options: JSONParsingOptions) {
        self.bytes = bytes
        self.index = 0
        self.options = options
    }

    mutating func parseTopLevel() throws -> StructuredValue {
        skipWhitespace()
        let value = try parseValue(depth: 0)
        skipWhitespace()
        guard index == bytes.count else { throw error(.trailingData) }
        return value
    }

    private mutating func parseValue(depth: Int) throws -> StructuredValue {
        guard depth <= options.maximumDepth else { throw error(.depthLimitExceeded(options.maximumDepth)) }
        guard let byte = peek() else { throw error(.unexpectedEndOfInput) }
        switch byte {
        case UInt8(ascii: "{"): return try parseObject(depth: depth)
        case UInt8(ascii: "["): return try parseArray(depth: depth)
        case UInt8(ascii: "\""): return .string(try parseString())
        case UInt8(ascii: "t"): try expect("true"); return .bool(true)
        case UInt8(ascii: "f"): try expect("false"); return .bool(false)
        case UInt8(ascii: "n"): try expect("null"); return .null
        case UInt8(ascii: "-"), UInt8(ascii: "0")...UInt8(ascii: "9"):
            return .number(try parseNumber())
        default:
            throw error(.unexpectedCharacter(Character(UnicodeScalar(byte))))
        }
    }

    private mutating func parseObject(depth: Int) throws -> StructuredValue {
        advance()
        skipWhitespace()
        var raw: [(key: String, value: StructuredValue)] = []
        if peek() == UInt8(ascii: "}") { advance(); return .object(OrderedObject(raw)) }
        while true {
            skipWhitespace()
            guard peek() == UInt8(ascii: "\"") else { throw error(.malformed("expected object key")) }
            let key = try parseString()
            skipWhitespace()
            guard peek() == UInt8(ascii: ":") else { throw error(.malformed("expected ':'")) }
            advance()
            skipWhitespace()
            let value = try parseValue(depth: depth + 1)
            raw.append((key, value))
            skipWhitespace()
            switch peek() {
            case UInt8(ascii: ","): advance()
            case UInt8(ascii: "}"):
                advance()
                guard let object = OrderedObject.make(from: raw, policy: options.duplicateKeyPolicy) else {
                    throw error(.duplicateKey(raw.map(\.key).first ?? ""))
                }
                return .object(object)
            default: throw error(.malformed("expected ',' or '}'"))
            }
        }
    }

    private mutating func parseArray(depth: Int) throws -> StructuredValue {
        advance()
        skipWhitespace()
        var elements: [StructuredValue] = []
        if peek() == UInt8(ascii: "]") { advance(); return .array(elements) }
        while true {
            skipWhitespace()
            elements.append(try parseValue(depth: depth + 1))
            skipWhitespace()
            switch peek() {
            case UInt8(ascii: ","): advance()
            case UInt8(ascii: "]"): advance(); return .array(elements)
            default: throw error(.malformed("expected ',' or ']'"))
            }
        }
    }

    // MARK: Scalars

    private mutating func parseNumber() throws -> StructuredNumber {
        let start = index
        if peek() == UInt8(ascii: "-") { advance() }
        try parseIntegerPart()
        if peek() == UInt8(ascii: ".") {
            advance()
            try parseDigits(atLeastOne: true)
        }
        if peek() == UInt8(ascii: "e") || peek() == UInt8(ascii: "E") {
            advance()
            if peek() == UInt8(ascii: "+") || peek() == UInt8(ascii: "-") { advance() }
            try parseDigits(atLeastOne: true)
        }
        let text = String(decoding: bytes[start..<index], as: UTF8.self)
        return StructuredNumber(unchecked: text)
    }

    private mutating func parseIntegerPart() throws {
        guard let byte = peek(), byte >= UInt8(ascii: "0"), byte <= UInt8(ascii: "9") else {
            throw error(.invalidNumber("missing integer digits"))
        }
        if byte == UInt8(ascii: "0") {
            advance()
            if let next = peek(), next >= UInt8(ascii: "0"), next <= UInt8(ascii: "9") {
                throw error(.invalidNumber("leading zero"))
            }
        } else {
            try parseDigits(atLeastOne: true)
        }
    }

    private mutating func parseDigits(atLeastOne: Bool) throws {
        var count = 0
        while let byte = peek(), byte >= UInt8(ascii: "0"), byte <= UInt8(ascii: "9") {
            advance()
            count += 1
        }
        if atLeastOne && count == 0 { throw error(.invalidNumber("expected digit")) }
    }

    private mutating func parseString() throws -> String {
        advance()
        var buffer: [UInt8] = []
        while true {
            guard let byte = peek() else { throw error(.unexpectedEndOfInput) }
            switch byte {
            case UInt8(ascii: "\""):
                advance()
                guard let string = String(bytes: buffer, encoding: .utf8) else { throw error(.invalidUTF8) }
                return string
            case UInt8(ascii: "\\"):
                advance()
                try parseEscape(into: &buffer)
            case 0x00...0x1F:
                throw error(.malformed("unescaped control character"))
            default:
                buffer.append(byte)
                advance()
            }
        }
    }

    private mutating func parseEscape(into buffer: inout [UInt8]) throws {
        guard let byte = peek() else { throw error(.unexpectedEndOfInput) }
        switch byte {
        case UInt8(ascii: "\""): buffer.append(byte); advance()
        case UInt8(ascii: "\\"): buffer.append(byte); advance()
        case UInt8(ascii: "/"): buffer.append(byte); advance()
        case UInt8(ascii: "b"): buffer.append(0x08); advance()
        case UInt8(ascii: "f"): buffer.append(0x0C); advance()
        case UInt8(ascii: "n"): buffer.append(0x0A); advance()
        case UInt8(ascii: "r"): buffer.append(0x0D); advance()
        case UInt8(ascii: "t"): buffer.append(0x09); advance()
        case UInt8(ascii: "u"): try parseUnicodeEscape(into: &buffer)
        default: throw error(.invalidEscape(String(UnicodeScalar(byte))))
        }
    }

    private mutating func parseUnicodeEscape(into buffer: inout [UInt8]) throws {
        advance()
        let high = try parseHex4()
        if (0xD800...0xDBFF).contains(high) {
            if peek() == UInt8(ascii: "\\"), peekAt(1) == UInt8(ascii: "u") {
                advance(); advance()
                let low = try parseHex4()
                guard (0xDC00...0xDFFF).contains(low) else {
                    appendScalar(0xFFFD, into: &buffer)
                    appendScalar(UInt32(low), into: &buffer)
                    return
                }
                let scalar = 0x10000 + (UInt32(high - 0xD800) << 10) + UInt32(low - 0xDC00)
                appendScalar(scalar, into: &buffer)
            } else {
                appendScalar(0xFFFD, into: &buffer)
            }
        } else if (0xDC00...0xDFFF).contains(high) {
            appendScalar(0xFFFD, into: &buffer)
        } else {
            appendScalar(UInt32(high), into: &buffer)
        }
    }

    private mutating func parseHex4() throws -> UInt16 {
        var result: UInt16 = 0
        for _ in 0..<4 {
            guard let byte = peek(), let digit = hexValue(byte) else { throw error(.invalidEscape("\\u")) }
            result = (result << 4) | UInt16(digit)
            advance()
        }
        return result
    }

    private func appendScalar(_ scalar: UInt32, into buffer: inout [UInt8]) {
        guard let unicode = UnicodeScalar(scalar) else {
            buffer.append(contentsOf: [0xEF, 0xBF, 0xBD])
            return
        }
        UTF8.encode(unicode) { buffer.append($0) }
    }

    // MARK: Primitives

    private func peek() -> UInt8? { index < bytes.count ? bytes[index] : nil }
    private func peekAt(_ offset: Int) -> UInt8? { index + offset < bytes.count ? bytes[index + offset] : nil }
    private mutating func advance() { index += 1 }

    private mutating func skipWhitespace() {
        while let byte = peek(), byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D {
            advance()
        }
    }

    private mutating func expect(_ literal: String) throws {
        for scalar in literal.unicodeScalars {
            guard peek() == UInt8(scalar.value) else {
                throw error(.malformed("expected '\(literal)'"))
            }
            advance()
        }
    }

    private func hexValue(_ byte: UInt8) -> UInt8? {
        switch byte {
        case UInt8(ascii: "0")...UInt8(ascii: "9"): return byte - UInt8(ascii: "0")
        case UInt8(ascii: "a")...UInt8(ascii: "f"): return byte - UInt8(ascii: "a") + 10
        case UInt8(ascii: "A")...UInt8(ascii: "F"): return byte - UInt8(ascii: "A") + 10
        default: return nil
        }
    }

    private func error(_ kind: ParseError.Kind) -> ParseError {
        var line = 1, column = 1
        for offset in 0..<min(index, bytes.count) {
            if bytes[offset] == 0x0A { line += 1; column = 1 } else { column += 1 }
        }
        return ParseError(kind, at: SourceLocation(line: line, column: column, offset: index))
    }
}
