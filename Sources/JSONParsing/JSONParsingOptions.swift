import StructuredDataCore

/// Strictness knobs for the RFC 8259 parser.
public struct JSONParsingOptions: Sendable {
    public var duplicateKeyPolicy: DuplicateKeyPolicy
    /// Maximum nesting depth; bounds recursion to guard against stack-exhaustion DoS.
    public var maximumDepth: Int

    public init(duplicateKeyPolicy: DuplicateKeyPolicy = .lastWins, maximumDepth: Int = 128) {
        self.duplicateKeyPolicy = duplicateKeyPolicy
        self.maximumDepth = maximumDepth
    }

    /// RFC 7493 (I-JSON) leaning: reject duplicate names.
    public static let strict = JSONParsingOptions(duplicateKeyPolicy: .reject)
}
