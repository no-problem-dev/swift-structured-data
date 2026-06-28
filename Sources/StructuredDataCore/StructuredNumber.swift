import Foundation

/// A JSON-grammar number preserved as its original decimal text.
///
/// JSON numbers have no defined precision and no integer/real distinction, so
/// eagerly converting to `Double` loses information for values such as
/// `9223372036854775808` or `0.1`. `StructuredNumber` keeps the source text and
/// defers conversion until a concrete Swift type is requested, mirroring Go's
/// `json.Number` and serde's arbitrary-precision mode.
public struct StructuredNumber: Sendable, Hashable {
    /// The original textual representation, guaranteed to match the JSON number grammar.
    public let text: String

    /// Wraps text already known to be a valid JSON number (e.g. produced by a parser).
    public init(unchecked text: String) {
        self.text = text
    }

    /// Wraps text only if it conforms to the JSON number grammar.
    public init?(validating text: String) {
        guard StructuredNumber.isValid(text) else { return nil }
        self.text = text
    }

    /// The value as `Int`, or `nil` if the text does not represent an exact integer.
    public var int: Int? { Int(text) }
    /// The value as `Int64`, or `nil` if the text does not represent an exact 64-bit integer.
    public var int64: Int64? { Int64(text) }
    /// The value as `UInt64`, or `nil` if the text does not represent an exact unsigned 64-bit integer.
    public var uint64: UInt64? { UInt64(text) }

    /// The value as a `Decimal`, preserving more precision than `Double` for in-range values.
    public var decimal: Decimal? { Decimal(string: text) }

    /// The value as a `Double`. Lossy for magnitudes beyond IEEE-754 exact range.
    public var double: Double { Double(text) ?? .nan }

    public static func == (lhs: StructuredNumber, rhs: StructuredNumber) -> Bool {
        lhs.canonical == rhs.canonical
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(canonical)
    }
}

extension StructuredNumber: ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral {
    public init(integerLiteral value: Int) { self.text = String(value) }
    public init(floatLiteral value: Double) { self.text = String(value) }
}

extension StructuredNumber: CustomStringConvertible {
    public var description: String { text }
}

extension StructuredNumber {
    /// Canonical numeric identity used for equality and hashing.
    ///
    /// Two numbers are equal when they denote the same mathematical value, so
    /// `1`, `1.0`, `1e0`, and `100e-2`(==1) all compare equal while arbitrary
    /// precision is retained (comparison is purely textual, never via `Double`).
    fileprivate struct Canonical: Hashable {
        var negative: Bool
        var digits: String
        var pointExponent: Int
    }

    fileprivate var canonical: Canonical {
        var chars = Substring(text)
        var negative = false
        if chars.first == "-" { negative = true; chars = chars.dropFirst() }
        else if chars.first == "+" { chars = chars.dropFirst() }

        var mantissa = ""
        var fractionLength = 0
        var explicitExponent = 0
        var seenDot = false
        var index = chars.startIndex
        while index < chars.endIndex {
            let ch = chars[index]
            if ch == "." {
                seenDot = true
            } else if ch == "e" || ch == "E" {
                explicitExponent = Int(chars[chars.index(after: index)...]) ?? 0
                break
            } else {
                mantissa.append(ch)
                if seenDot { fractionLength += 1 }
            }
            index = chars.index(after: index)
        }

        var pointExponent = explicitExponent - fractionLength
        var digits = Substring(mantissa).drop(while: { $0 == "0" })
        while digits.last == "0" {
            digits = digits.dropLast()
            pointExponent += 1
        }
        if digits.isEmpty {
            return Canonical(negative: false, digits: "0", pointExponent: 0)
        }
        return Canonical(negative: negative, digits: String(digits), pointExponent: pointExponent)
    }

    private static func isValid(_ text: String) -> Bool {
        var chars = Substring(text)
        if chars.first == "-" { chars = chars.dropFirst() }
        guard let first = chars.first, first.isNumber else { return false }
        if first == "0", chars.count > 1 {
            let second = chars[chars.index(after: chars.startIndex)]
            if second.isNumber { return false }
        }
        var sawDot = false, sawExp = false, expectDigitAfter = false
        var previous: Character?
        for ch in chars {
            switch ch {
            case "0"..."9":
                expectDigitAfter = false
            case ".":
                if sawDot || sawExp { return false }
                sawDot = true; expectDigitAfter = true
            case "e", "E":
                if sawExp { return false }
                sawExp = true; expectDigitAfter = true
            case "+", "-":
                if previous != "e" && previous != "E" { return false }
                expectDigitAfter = true
            default:
                return false
            }
            previous = ch
        }
        return !expectDigitAfter
    }
}
