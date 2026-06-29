import Foundation

/// JSON 文法の数値を元の十進テキストのまま保持する型。
///
/// JSON 数値には定義済み精度も整数/実数の区別もないため、`Double` に即変換すると `9223372036854775808` や `0.1` のような値で情報が失われる。
/// `StructuredNumber` はソーステキストを保持し、具体的な Swift 型が要求されるまで変換を遅延する。Go の `json.Number` や serde の任意精度モードに倣った設計。
public struct StructuredNumber: Sendable, Hashable {
    /// JSON 数値文法に準拠することが保証された元のテキスト表現。
    public let text: String

    /// JSON 数値として妥当であることが既知のテキストをラップする（パーサが生成した値など）。
    public init(unchecked text: String) {
        self.text = text
    }

    /// JSON 数値文法に準拠する場合のみテキストをラップする。
    public init?(validating text: String) {
        guard StructuredNumber.isValid(text) else { return nil }
        self.text = text
    }

    /// `Int` として取り出した値。テキストが正確な整数を表さない場合は `nil`。
    public var int: Int? { Int(text) }
    /// `Int64` として取り出した値。テキストが正確な 64 ビット整数を表さない場合は `nil`。
    public var int64: Int64? { Int64(text) }
    /// `UInt64` として取り出した値。テキストが正確な符号なし 64 ビット整数を表さない場合は `nil`。
    public var uint64: UInt64? { UInt64(text) }

    /// `Decimal` として取り出した値。範囲内の値では `Double` よりも精度を保持する。
    public var decimal: Decimal? { Decimal(string: text) }

    /// `Double` として取り出した値。IEEE-754 の正確な範囲を超える大きさではロスが生じる。
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
    /// 等値判定とハッシュに使う正規化済み数値表現。
    ///
    /// 同じ数学的値を示せば等しいとみなすため、`1`、`1.0`、`1e0`、`100e-2`（==1）は全て等しい。
    /// 比較はテキストのみで行い、`Double` を経由しない。
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
