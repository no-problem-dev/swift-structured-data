import Foundation
import StructuredDataCore

/// A strict RFC 8259 and ECMA-404 parser that keeps every number's source text intact.
///
/// Accepts the grammar and nothing more: no trailing commas, no comments, no single quotes, no
/// unquoted keys, no `NaN` or `Infinity`, no byte-order mark, and no bytes after the top-level
/// value. A top-level scalar is valid. What happens to a repeated key is the one thing left to
/// choose, and ``JSONParsingOptions`` chooses it.
///
/// Numbers arrive as ``StructuredNumber`` holding the digits as written, so nothing is rounded
/// until you ask for a concrete type. Use ``StreamingJSONParser`` when the input may be a
/// truncated prefix rather than a whole document.
public struct JSONParser: DataParser {
    public var options: JSONParsingOptions

    public init(options: JSONParsingOptions = .init()) {
        self.options = options
    }

    public func parse(_ data: Data) throws -> StructuredValue {
        var scanner = JSONScanner(bytes: Array(data), options: options)
        return try scanner.parseTopLevel()
    }

    public func parse(_ string: String) throws -> StructuredValue {
        try parse(Data(string.utf8))
    }
}
