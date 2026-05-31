import StructuredDataCore

/// Resolves a plain (unquoted) scalar to a typed value using the YAML 1.2 Core
/// schema.
///
/// Core, unlike YAML 1.1, treats `yes/no/on/off` and `NO` as strings — the
/// "Norway problem" is fixed. Booleans are only `true`/`false` (any case),
/// integers support `0o` octal and `0x` hex, and `~`/`null`/empty are null.
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
