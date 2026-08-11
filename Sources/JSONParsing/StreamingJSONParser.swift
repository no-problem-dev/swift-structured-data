import Foundation
import StructuredDataCore

/// Accumulates JSON that arrives in pieces, such as an LLM token stream, and reads it at any point.
///
/// Two readings of the same buffer. ``snapshot()`` closes whatever is still open and drops the
/// trailing partial token, so a UI can draw a partly-received object on every chunk without
/// waiting; it never throws and returns null when nothing usable has arrived yet. ``finish()``
/// parses the accumulated bytes strictly and is the one that tells you whether what arrived was
/// actually valid.
///
/// The buffer only grows — consumed bytes are re-parsed on every snapshot, so this suits
/// response-sized payloads rather than an unbounded feed.
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

    /// The best reading of the bytes received so far, with open structures closed and any trailing partial token dropped.
    ///
    /// Never throws: a buffer holding nothing parseable yet reads as null. Values near the end of
    /// the buffer may change as more arrives, so treat a snapshot as provisional until
    /// ``finish()`` succeeds.
    public func snapshot() -> StructuredValue {
        var scanner = TolerantJSONScanner(bytes: buffer, maximumDepth: maximumDepth)
        return scanner.parse()
    }

    /// Parses everything accumulated as one complete document, under the full strict grammar.
    ///
    /// Throws if the stream ended early or was malformed, which is the only way to learn that a
    /// snapshot was showing a truncated reading.
    public func finish() throws -> StructuredValue {
        try JSONParser(options: .init(maximumDepth: maximumDepth)).parse(Data(buffer))
    }
}
