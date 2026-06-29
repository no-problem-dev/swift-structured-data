/// 診断用のソーステキスト上の位置。
public struct SourceLocation: Sendable, Hashable, CustomStringConvertible {
    public var line: Int
    public var column: Int
    public var offset: Int

    public init(line: Int, column: Int, offset: Int) {
        self.line = line
        self.column = column
        self.offset = offset
    }

    public var description: String { "line \(line):\(column)" }
}

/// 型変換が行われる前の Layer 1 パーサが生成するエラー。
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
