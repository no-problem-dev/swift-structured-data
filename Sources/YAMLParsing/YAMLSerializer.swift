import Foundation
import StructuredDataCore

/// Writes a value as YAML in the same Core subset the parser reads, so a round trip returns the value unchanged.
///
/// Non-empty collections are written in block style and empty ones inline as `[]` and `{}`.
///
/// A string is written plain only when reading it back plain would give the same string, and
/// double-quoted otherwise, which is what keeps `"1.0"` and `"true"` from coming back as a number
/// and a boolean. Numbers are written from their stored text, so a number built outside the JSON
/// grammar is reproduced as-is.
///
/// The output uses no tags, anchors, aliases or complex keys, matching the subset the parser
/// understands — a document that needs any of them cannot be produced here.
public struct YAMLSerializer: DataSerializer {
    public struct Options: Sendable {
        /// Sorts mapping keys alphabetically instead of writing them in source order.
        public var sortKeys: Bool
        /// The indent added per nesting level, which must contain at least one space.
        ///
        /// Indentation is the only thing marking nesting in block style, so an empty string here
        /// produces output the parser reads back flat.
        public var indent: String

        public init(sortKeys: Bool = false, indent: String = "  ") {
            self.sortKeys = sortKeys
            self.indent = indent
        }
    }

    public var options: Options

    public init(options: Options = .init()) {
        self.options = options
    }

    public func serialize(_ value: StructuredValue) throws -> Data {
        Data(string(from: value).utf8)
    }

    public func string(from value: StructuredValue) -> String {
        var output = ""
        switch value {
        case .object(let object) where !object.isEmpty:
            writeMapping(object, depth: 0, into: &output)
        case .array(let array) where !array.isEmpty:
            writeSequence(array, depth: 0, into: &output)
        default:
            output += inlineScalar(value) + "\n"
        }
        return output
    }

    // MARK: - Block writers

    private func writeMapping(_ object: OrderedObject, depth: Int, into output: inout String) {
        let pad = String(repeating: options.indent, count: depth)
        let entries = options.sortKeys ? object.entries.sorted { $0.key < $1.key } : object.entries
        for entry in entries {
            let key = scalar(entry.key)
            switch entry.value {
            case .object(let child) where !child.isEmpty:
                output += pad + key + ":\n"
                writeMapping(child, depth: depth + 1, into: &output)
            case .array(let child) where !child.isEmpty:
                output += pad + key + ":\n"
                writeSequence(child, depth: depth + 1, into: &output)
            default:
                output += pad + key + ": " + inlineScalar(entry.value) + "\n"
            }
        }
    }

    private func writeSequence(_ array: [StructuredValue], depth: Int, into output: inout String) {
        let pad = String(repeating: options.indent, count: depth)
        for element in array {
            switch element {
            case .object(let child) where !child.isEmpty:
                output += pad + "-\n"
                writeMapping(child, depth: depth + 1, into: &output)
            case .array(let child) where !child.isEmpty:
                output += pad + "-\n"
                writeSequence(child, depth: depth + 1, into: &output)
            default:
                output += pad + "- " + inlineScalar(element) + "\n"
            }
        }
    }

    // MARK: - Scalars

    private func inlineScalar(_ value: StructuredValue) -> String {
        switch value {
        case .null: return "null"
        case .bool(let bool): return bool ? "true" : "false"
        case .number(let number): return number.text
        case .string(let string): return scalar(string)
        case .array(let array): return array.isEmpty ? "[]" : "[]"
        case .object(let object): return object.isEmpty ? "{}" : "{}"
        }
    }

    /// A string scalar (used for both keys and values): plain when it survives a
    /// plain round-trip, double-quoted otherwise.
    private func scalar(_ string: String) -> String {
        Self.plainIsSafe(string) ? string : doubleQuoted(string)
    }

    /// Whether writing this string unquoted would read back as the same string.
    ///
    /// False for anything the Core schema would resolve as null, a boolean or a number; for
    /// leading or trailing spaces, which the block parser trims; for control characters, which a
    /// plain scalar cannot hold; for a leading indicator character, which changes how the line is
    /// read; and for the sequences that would start a mapping or a comment.
    static func plainIsSafe(_ string: String) -> Bool {
        guard !string.isEmpty else { return false }
        // Would a plain scalar coerce to null/bool/number under the Core schema?
        guard case .string = YAMLScalarResolver.resolve(string) else { return false }
        // Leading/trailing spaces are trimmed away by the block parser.
        if string.first == " " || string.last == " " { return false }
        // Control characters (incl. newline/tab) cannot live in a plain scalar.
        if string.unicodeScalars.contains(where: { $0.value < 0x20 }) { return false }
        // A leading indicator character changes how the line is parsed.
        if let first = string.first, Self.leadingIndicators.contains(first) { return false }
        // `: ` / trailing `:` start a mapping; ` #` starts a comment.
        if string.contains(": ") || string.hasSuffix(":") || string.contains(" #") { return false }
        return true
    }

    private static let leadingIndicators: Set<Character> = [
        "-", "?", ":", ",", "[", "]", "{", "}", "#", "&", "*", "!", "|", ">", "'", "\"", "%", "@", "`",
    ]

    private func doubleQuoted(_ string: String) -> String {
        var out = "\""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\t": out += "\\t"
            case "\r": out += "\\r"
            case let c where c.value < 0x20:
                out += String(format: "\\u%04X", c.value)
            default:
                out.unicodeScalars.append(scalar)
            }
        }
        out += "\""
        return out
    }
}
