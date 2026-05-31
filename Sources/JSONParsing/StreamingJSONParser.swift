import Foundation
import StructuredDataCore

/// Accumulates JSON delivered in chunks (e.g. an LLM token stream) and exposes
/// the best-effort value parsed so far.
///
/// ``snapshot()`` tolerantly closes open structures and drops a trailing
/// incomplete token, so a UI can render a partial object as it streams.
/// ``finish()`` performs a strict parse of the complete buffer.
public struct StreamingJSONParser: Sendable {
    private var buffer: [UInt8] = []
    private let maximumDepth: Int

    public init(maximumDepth: Int = 128) {
        self.maximumDepth = maximumDepth
    }

    public mutating func consume(_ chunk: Data) {
        buffer.append(contentsOf: chunk)
    }

    public mutating func consume(_ chunk: String) {
        buffer.append(contentsOf: chunk.utf8)
    }

    /// The value understood from the bytes received so far. Never throws.
    public func snapshot() -> StructuredValue {
        var scanner = TolerantJSONScanner(bytes: buffer, maximumDepth: maximumDepth)
        return scanner.parse()
    }

    /// Strictly parses the accumulated buffer as a complete document.
    public func finish() throws -> StructuredValue {
        try JSONParser(options: .init(maximumDepth: maximumDepth)).parse(Data(buffer))
    }
}
