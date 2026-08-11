import StructuredDataCore

/// Decides what an unquoted scalar means under the YAML 1.2 Core schema, where far fewer words are booleans.
///
/// Core is the schema that fixed the Norway problem: `yes`, `no`, `on`, `off` and `NO` are strings
/// here, not booleans, so a country code stays a country code. Only quoting can change what a
/// scalar means, and quoting always yields a string.
///
/// The exact resolution, in order:
///
/// - **Null** — the empty string, `~`, `null`, `Null`, `NULL`.
/// - **Boolean** — `true`, `True`, `TRUE`, `false`, `False`, `FALSE`. These six spellings and no
///   others: the match is not case-insensitive, so `tRue` is a string. That is not a shortcut —
///   it is the Core schema's boolean rule exactly, which admits lowercase, capitalised and
///   uppercase and nothing between. Widening it would put this back on the 1.1 side of the same
///   line that makes `no` a string here.
/// - **Integer** — an optional sign then decimal digits, or a `0o` octal or `0x` hexadecimal body.
///   The two radix forms are converted to decimal, so unlike every other number here their source
///   spelling is not preserved. Leading zeros are preserved, which means `007` becomes a number
///   whose text is not valid JSON. Digit separators are not understood, so `1_000` is a string.
/// - **Float** — anything matching the JSON number grammar, kept verbatim. That grammar is
///   narrower than YAML's, so `.inf`, `.nan`, `.5` and a signed `+1.5` all fall through to string.
/// - **String** — everything else.
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
