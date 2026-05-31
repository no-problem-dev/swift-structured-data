import Foundation
import StructuredDataCore

/// Serializes a ``StructuredValue`` into RFC 8259 JSON bytes.
public struct JSONSerializer: DataSerializer {
    public struct Options: Sendable {
        public var prettyPrinted: Bool
        public var sortKeys: Bool
        public var indent: String

        public init(prettyPrinted: Bool = false, sortKeys: Bool = false, indent: String = "  ") {
            self.prettyPrinted = prettyPrinted
            self.sortKeys = sortKeys
            self.indent = indent
        }
    }

    public var options: Options

    public init(options: Options = .init()) {
        self.options = options
    }

    public func serialize(_ value: StructuredValue) throws -> Data {
        var output = ""
        write(value, depth: 0, into: &output)
        return Data(output.utf8)
    }

    public func string(from value: StructuredValue) -> String {
        var output = ""
        write(value, depth: 0, into: &output)
        return output
    }

    private func write(_ value: StructuredValue, depth: Int, into output: inout String) {
        switch value {
        case .null: output += "null"
        case .bool(let bool): output += bool ? "true" : "false"
        case .number(let number): output += number.text
        case .string(let string): writeString(string, into: &output)
        case .array(let array): writeArray(array, depth: depth, into: &output)
        case .object(let object): writeObject(object, depth: depth, into: &output)
        }
    }

    private func writeArray(_ array: [StructuredValue], depth: Int, into output: inout String) {
        guard !array.isEmpty else { output += "[]"; return }
        output += "["
        for (offset, element) in array.enumerated() {
            if offset > 0 { output += "," }
            newline(depth + 1, into: &output)
            write(element, depth: depth + 1, into: &output)
        }
        newline(depth, into: &output)
        output += "]"
    }

    private func writeObject(_ object: OrderedObject, depth: Int, into output: inout String) {
        guard !object.isEmpty else { output += "{}"; return }
        let entries = options.sortKeys ? object.entries.sorted { $0.key < $1.key } : object.entries
        output += "{"
        for (offset, entry) in entries.enumerated() {
            if offset > 0 { output += "," }
            newline(depth + 1, into: &output)
            writeString(entry.key, into: &output)
            output += options.prettyPrinted ? ": " : ":"
            write(entry.value, depth: depth + 1, into: &output)
        }
        newline(depth, into: &output)
        output += "}"
    }

    private func writeString(_ string: String, into output: inout String) {
        output += "\""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\"": output += "\\\""
            case "\\": output += "\\\\"
            case "\u{08}": output += "\\b"
            case "\u{0C}": output += "\\f"
            case "\n": output += "\\n"
            case "\r": output += "\\r"
            case "\t": output += "\\t"
            case let s where s.value < 0x20:
                output += String(format: "\\u%04x", s.value)
            default:
                output.unicodeScalars.append(scalar)
            }
        }
        output += "\""
    }

    private func newline(_ depth: Int, into output: inout String) {
        guard options.prettyPrinted else { return }
        output += "\n"
        output += String(repeating: options.indent, count: depth)
    }
}
