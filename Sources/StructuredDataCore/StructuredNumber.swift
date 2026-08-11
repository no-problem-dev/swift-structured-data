import Foundation

/// A number kept as the decimal text it was written as, converted only when a Swift type is asked for.
///
/// JSON numbers have neither a defined precision nor an integer/real distinction, so converting
/// eagerly to `Double` destroys information in values such as `9223372036854775808` and `0.1`.
/// This type stores the source text byte for byte — its exponent spelling, its sign, its trailing
/// zeros — and every accessor converts from that text. Nothing is narrowed on the way in, so an
/// integer literal too large for `Int64` still arrives intact and is readable through ``uint64``
/// or ``decimal``. Precision is lost only at the accessor you pick, never at parse time.
/// Modelled on Go's `json.Number` and serde's arbitrary-precision mode.
///
/// Equality and hashing compare mathematical value, not spelling, and never route through
/// `Double`: the text is reduced to a sign, its significant digits and a decimal exponent, so
/// `1`, `1.0`, `1e0` and `100e-2` are one value, and `-0` equals `0`. Two numbers can therefore
/// be equal while their ``text`` — and hence their serialized form — differs.
public struct StructuredNumber: Sendable, Hashable {
    /// The number exactly as it was written in the source, and exactly as a serializer will write it back.
    ///
    /// Parsers only ever store text that satisfies the JSON number grammar. ``init(unchecked:)``
    /// stores whatever it is handed, so this can also hold text no JSON parser would accept.
    public let text: String

    /// Stores text already known to be a JSON number, such as a parser's own slice of the input.
    ///
    /// Nothing is checked. Text outside the JSON grammar — `007`, `inf`, `nan`, `0x1F` — is stored
    /// as given and written back verbatim by serializers, producing output that will not parse.
    /// Round-tripping through a Swift `Double` reaches here too: `String(Double.infinity)` is
    /// `"inf"`, so encoding a non-finite `Double` yields invalid JSON rather than an error.
    public init(unchecked text: String) {
        self.text = text
    }

    /// Stores text only if it is a valid JSON number, and returns nil otherwise.
    ///
    /// Applies the RFC 8259 grammar: an optional leading `-`, no redundant leading zero, at least
    /// one digit on each side of a decimal point, and at least one digit after any exponent
    /// marker. So `+1`, `.5`, `5.`, `01`, `1e`, `NaN` and `Infinity` are all rejected, while
    /// `1e999` is accepted — the grammar bounds the spelling, not the magnitude.
    public init?(validating text: String) {
        guard StructuredNumber.isValid(text) else { return nil }
        self.text = text
    }

    /// The value when it is spelled as a plain integer, and nil when it is not.
    ///
    /// This tests the spelling, not the quantity: `1.0` and `1e2` both give nil even though they
    /// denote whole numbers, and so does any literal outside `Int`'s range. Use ``coercedInt``
    /// when you want those forms accepted.
    public var int: Int? { Int(text) }
    /// The value when it is spelled as a plain integer that fits in 64 bits, and nil when it is not.
    ///
    /// A literal above `Int64.max` gives nil here but still reads through ``uint64``, because the
    /// digits were never discarded.
    public var int64: Int64? { Int64(text) }
    /// The value when it is spelled as a plain non-negative integer that fits in 64 bits, and nil when it is not.
    public var uint64: UInt64? { UInt64(text) }

    /// The value as a decimal, which keeps far more digits than a double within its range.
    ///
    /// This is the accessor to reach for with money and with any literal whose digits matter.
    /// Returns nil when the text cannot be represented as a `Decimal` at all.
    public var decimal: Decimal? { Decimal(string: text) }

    /// The value as a double, rounded to the nearest representable one.
    ///
    /// Everything past 17 significant digits is lost, and the loss is silent. A magnitude beyond
    /// the IEEE-754 range becomes infinity rather than an error, one below it flushes to zero, and
    /// text that is not a number at all — reachable only through ``init(unchecked:)`` — gives NaN.
    ///
    /// This is the lenient accessor, for exploring a payload where a rough answer is what is
    /// wanted. ``exactDouble`` is the one that refuses to answer instead of answering infinity.
    public var double: Double { Double(text) ?? .nan }

    /// The value as a double, or nil when a double cannot hold it.
    ///
    /// The same conversion as ``double``, minus the two results that are not the number at all:
    /// infinity, which is what a magnitude beyond the IEEE-754 range collapses to, and NaN, which
    /// is what text outside the number grammar gives.
    ///
    /// **Rounding is not overflow, so rounding still happens here.** `0.1` has no exact double and
    /// arrives rounded, and `1e-400` arrives as zero, because in both cases the double returned is
    /// the nearest representable value to the number written. `1e400` has no nearest representable
    /// value — infinity is not a large number, it is the absence of one — so this returns nil.
    public var exactDouble: Double? {
        guard let value = Double(text), value.isFinite else { return nil }
        return value
    }

    /// The value as a float, or nil when a float cannot hold it, on the same terms as ``exactDouble``.
    ///
    /// The range is much narrower, so this refuses a good deal that ``exactDouble`` accepts:
    /// `1e300` is an ordinary double and no float at all.
    public var exactFloat: Float? {
        guard let value = Float(text), value.isFinite else { return nil }
        return value
    }

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
    /// The spelling-independent form that equality and hashing actually compare.
    ///
    /// A number reduces to its sign, its significant digits with leading and trailing zeros
    /// removed, and the decimal exponent implied by the point and any explicit exponent. Since
    /// this is derived from the text alone, no rounding enters the comparison.
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
