import Foundation
import StructuredDataCore

/// Serializes a ``StructuredValue`` into YAML 1.2 Core-schema text.
///
/// The inverse of ``YAMLParser`` over the same Core subset, guaranteeing
/// `parse(serialize(v)) == v`. Emits block style for non-empty collections and
/// flow (`[]` / `{}`) for empty ones. Scalars are emitted plain when they
/// resolve back to the same value, and double-quoted otherwise — so a string
/// like `"1.0"` survives as a string rather than coercing to a number.
///
/// Tags, anchors/aliases, and complex keys are out of scope (the parser drops
/// them), matching the round-trippable Core subset.
public struct YAMLSerializer: DataSerializer {
    public struct Options: Sendable {
        /// Sort mapping keys lexicographically instead of preserving insertion order.
        public var sortKeys: Bool
        /// Per-level indentation. Must be at least one space for the parser to
        /// distinguish nesting.
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

    /// `true` if emitting `string` plain reparses to exactly `.string(string)`.
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
