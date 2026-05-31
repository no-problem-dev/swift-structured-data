import Foundation
import StructuredDataCore

/// RFC 8259 / ECMA-404 parser producing the neutral ``StructuredValue``.
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
