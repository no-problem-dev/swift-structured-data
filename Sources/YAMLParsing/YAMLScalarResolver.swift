import StructuredDataCore

/// YAML 1.2 Core スキーマを用いてプレイン（非クォート）スカラーを型付き値へ解決する。
///
/// YAML 1.1 と異なり Core では `yes/no/on/off` や `NO` は文字列として扱われ、「ノルウェー問題」が解消されている。
/// Bool は `true`/`false`（大文字小文字不問）のみ。整数は `0o` 八進数と `0x` 十六進数をサポート。
/// `~`、`null`、空文字列はヌルとして解釈する。
enum YAMLScalarResolver {
    static func resolve(_ text: String) -> StructuredValue {
        switch text {
        case "", "~", "null", "Null", "NULL": return .null
        case "true", "True", "TRUE": return .bool(true)
        case "false", "False", "FALSE": return .bool(false)
        default: break
        }
        if let number = integer(text) ?? float(text) {
            return .number(number)
        }
        return .string(text)
    }

    private static func integer(_ text: String) -> StructuredNumber? {
        var body = Substring(text)
        var sign = ""
        if body.first == "-" || body.first == "+" {
            if body.first == "-" { sign = "-" }
            body = body.dropFirst()
        }
        if body.hasPrefix("0o"), body.count > 2 {
            let digits = body.dropFirst(2)
            guard digits.allSatisfy({ ("0"..."7").contains($0) }), let value = UInt64(digits, radix: 8) else { return nil }
            return StructuredNumber(unchecked: sign + String(value))
        }
        if body.hasPrefix("0x"), body.count > 2 {
            let digits = body.dropFirst(2)
            guard digits.allSatisfy(\.isHexDigit), let value = UInt64(digits, radix: 16) else { return nil }
            return StructuredNumber(unchecked: sign + String(value))
        }
        guard !body.isEmpty, body.allSatisfy({ ("0"..."9").contains($0) }) else { return nil }
        return StructuredNumber(unchecked: sign + String(body))
    }

    private static func float(_ text: String) -> StructuredNumber? {
        // JSON-grammar floats are kept verbatim; .inf/.nan are out of JSON scope.
        StructuredNumber(validating: text)
    }
}
