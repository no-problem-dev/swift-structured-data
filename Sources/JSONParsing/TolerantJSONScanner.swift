import StructuredDataCore

/// Best-effort parser for an incomplete JSON prefix.
///
/// Unlike ``JSONScanner`` it never throws: when input ends mid-structure it
/// returns the portion understood so far, dropping a trailing incomplete token.
/// This backs streaming decode of partial LLM output.
struct TolerantJSONScanner {
    private let bytes: [UInt8]
    private var index: Int
    private let maximumDepth: Int

    init(bytes: [UInt8], maximumDepth: Int) {
        self.bytes = bytes
        self.index = 0
        self.maximumDepth = maximumDepth
    }

    mutating func parse() -> StructuredValue {
        skipWhitespace()
        return parseValue(depth: 0) ?? .null
    }

    private mutating func parseValue(depth: Int) -> StructuredValue? {
        guard depth <= maximumDepth, let byte = peek() else { return nil }
        switch byte {
        case UInt8(ascii: "{"): return parseObject(depth: depth)
        case UInt8(ascii: "["): return parseArray(depth: depth)
        case UInt8(ascii: "\""): return parseString().map(StructuredValue.string)
        case UInt8(ascii: "t"): return matchKeyword("true").map { .bool(true) }
        case UInt8(ascii: "f"): return matchKeyword("false").map { .bool(false) }
        case UInt8(ascii: "n"): return matchKeyword("null").map { .null }
        case UInt8(ascii: "-"), UInt8(ascii: "0")...UInt8(ascii: "9"): return parseNumber()
        default: return nil
        }
    }

    private mutating func parseObject(depth: Int) -> StructuredValue {
        advance()
        var entries: [(key: String, value: StructuredValue)] = []
        while true {
            skipWhitespace()
            guard let byte = peek() else { break }
            if byte == UInt8(ascii: "}") { advance(); break }
            guard byte == UInt8(ascii: "\""), let key = parseString() else { break }
            skipWhitespace()
            guard peek() == UInt8(ascii: ":") else { break }
            advance()
            skipWhitespace()
            guard let value = parseValue(depth: depth + 1) else { break }
            entries.append((key, value))
            skipWhitespace()
            if peek() == UInt8(ascii: ",") { advance(); continue }
            if peek() == UInt8(ascii: "}") { advance() }
            break
        }
        return .object(OrderedObject(entries))
    }

    private mutating func parseArray(depth: Int) -> StructuredValue {
        advance()
        var elements: [StructuredValue] = []
        while true {
            skipWhitespace()
            guard let byte = peek() else { break }
            if byte == UInt8(ascii: "]") { advance(); break }
            guard let value = parseValue(depth: depth + 1) else { break }
            elements.append(value)
            skipWhitespace()
            if peek() == UInt8(ascii: ",") { advance(); continue }
            if peek() == UInt8(ascii: "]") { advance() }
            break
        }
        return .array(elements)
    }

    private mutating func parseString() -> String? {
        advance()
        var buffer: [UInt8] = []
        while let byte = peek() {
            if byte == UInt8(ascii: "\"") { advance(); return decode(buffer) }
            if byte == UInt8(ascii: "\\") {
                advance()
                guard appendEscape(into: &buffer) else { return decode(buffer) }
            } else if byte < 0x20 {
                return decode(buffer)
            } else {
                buffer.append(byte)
                advance()
            }
        }
        return decode(buffer)
    }

    private mutating func appendEscape(into buffer: inout [UInt8]) -> Bool {
        guard let byte = peek() else { return false }
        switch byte {
        case UInt8(ascii: "\""): buffer.append(byte)
        case UInt8(ascii: "\\"): buffer.append(byte)
        case UInt8(ascii: "/"): buffer.append(byte)
        case UInt8(ascii: "b"): buffer.append(0x08)
        case UInt8(ascii: "f"): buffer.append(0x0C)
        case UInt8(ascii: "n"): buffer.append(0x0A)
        case UInt8(ascii: "r"): buffer.append(0x0D)
        case UInt8(ascii: "t"): buffer.append(0x09)
        case UInt8(ascii: "u"):
            guard index + 4 < bytes.count else { return false }
            advance()
            var scalar: UInt32 = 0
            for _ in 0..<4 {
                guard let digit = hexValue(peek()) else { return false }
                scalar = (scalar << 4) | UInt32(digit)
                advance()
            }
            if let unicode = UnicodeScalar(scalar) { UTF8.encode(unicode) { buffer.append($0) } }
            return true
        default: return false
        }
        advance()
        return true
    }

    private mutating func parseNumber() -> StructuredValue? {
        let start = index
        if peek() == UInt8(ascii: "-") { advance() }
        while let byte = peek(), isNumberByte(byte) { advance() }
        let text = String(decoding: bytes[start..<index], as: UTF8.self)
        guard StructuredNumber(validating: text) != nil else { return nil }
        return .number(StructuredNumber(unchecked: text))
    }

    // MARK: Primitives

    private func decode(_ buffer: [UInt8]) -> String {
        var slice = buffer[...]
        while !slice.isEmpty {
            if let string = String(bytes: slice, encoding: .utf8) { return string }
            slice = slice.dropLast()
        }
        return ""
    }

    private mutating func matchKeyword(_ literal: String) -> Void? {
        for scalar in literal.unicodeScalars {
            guard peek() == UInt8(scalar.value) else { return nil }
            advance()
        }
        return ()
    }

    private func isNumberByte(_ byte: UInt8) -> Bool {
        switch byte {
        case UInt8(ascii: "0")...UInt8(ascii: "9"), UInt8(ascii: "."),
             UInt8(ascii: "e"), UInt8(ascii: "E"), UInt8(ascii: "+"), UInt8(ascii: "-"):
            return true
        default: return false
        }
    }

    private func hexValue(_ byte: UInt8?) -> UInt8? {
        guard let byte else { return nil }
        switch byte {
        case UInt8(ascii: "0")...UInt8(ascii: "9"): return byte - UInt8(ascii: "0")
        case UInt8(ascii: "a")...UInt8(ascii: "f"): return byte - UInt8(ascii: "a") + 10
        case UInt8(ascii: "A")...UInt8(ascii: "F"): return byte - UInt8(ascii: "A") + 10
        default: return nil
        }
    }

    private func peek() -> UInt8? { index < bytes.count ? bytes[index] : nil }
    private mutating func advance() { index += 1 }
    private mutating func skipWhitespace() {
        while let byte = peek(), byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D { advance() }
    }
}
