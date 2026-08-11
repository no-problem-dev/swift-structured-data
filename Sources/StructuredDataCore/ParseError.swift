/// A position in the source, counted in UTF-8 bytes rather than characters.
///
/// ``line`` and ``column`` both start at 1, and ``offset`` starts at 0. All three count bytes, so
/// a line of Japanese text reports a column several times larger than the number of characters
/// before the error — treat the column as a byte position within the line, not a caret position
/// for a monospaced diagnostic.
public struct SourceLocation: Sendable, Hashable, CustomStringConvertible {
    /// The 1-based line, counting only newline bytes as breaks.
    public var line: Int
    /// The 1-based byte position within the line, not a character or grapheme count.
    public var column: Int
    /// The 0-based byte offset from the start of the input.
    public var offset: Int

    public init(line: Int, column: Int, offset: Int) {
        self.line = line
        self.column = column
        self.offset = offset
    }

    public var description: String { "line \(line):\(column)" }
}

/// A syntax failure raised while reading bytes, before any conversion to a Swift type.
///
/// Failures that happen after parsing — a number that will not fit the requested type, a missing
/// key — arrive as `DecodingError` instead.
///
/// Only the strict JSON scanner fills in a ``location``; the YAML and XML parsers always leave it
/// nil, so for those formats the ``kind`` is the whole diagnostic.
public struct ParseError: Error, Sendable, CustomStringConvertible {
    public enum Kind: Sendable, Equatable {
        case unexpectedCharacter(Character)
        case unexpectedEndOfInput
        case invalidNumber(String)
        case invalidEscape(String)
        case invalidUnicodeScalar(String)
        case invalidUTF8
        case duplicateKey(String)
        case depthLimitExceeded(Int)
        case trailingData
        case malformed(String)
    }

    public let kind: Kind
    public let location: SourceLocation?

    public init(_ kind: Kind, at location: SourceLocation? = nil) {
        self.kind = kind
        self.location = location
    }

    public var description: String {
        let suffix = location.map { " at \($0)" } ?? ""
        switch kind {
        case .unexpectedCharacter(let ch): return "unexpected character '\(ch)'\(suffix)"
        case .unexpectedEndOfInput: return "unexpected end of input\(suffix)"
        case .invalidNumber(let text): return "invalid number '\(text)'\(suffix)"
        case .invalidEscape(let text): return "invalid escape '\(text)'\(suffix)"
        case .invalidUnicodeScalar(let text): return "invalid unicode scalar '\(text)'\(suffix)"
        case .invalidUTF8: return "invalid UTF-8\(suffix)"
        case .duplicateKey(let key): return "duplicate key '\(key)'\(suffix)"
        case .depthLimitExceeded(let limit): return "nesting depth exceeded \(limit)\(suffix)"
        case .trailingData: return "unexpected trailing data\(suffix)"
        case .malformed(let reason): return "malformed input: \(reason)\(suffix)"
        }
    }
}
