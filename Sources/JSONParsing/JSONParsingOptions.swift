import StructuredDataCore

/// The two things RFC 8259 leaves to the implementation: repeated keys and how deep to recurse.
public struct JSONParsingOptions: Sendable {
    public var duplicateKeyPolicy: DuplicateKeyPolicy
    /// How many levels of nesting to accept before failing, bounding the parser's stack use.
    ///
    /// The parser recurses per level, so an adversarial document of nothing but open brackets
    /// would otherwise exhaust the stack and crash the process rather than throw. Nesting is
    /// counted from zero at the top-level value, so the default of 128 admits 129 levels.
    public var maximumDepth: Int

    public init(duplicateKeyPolicy: DuplicateKeyPolicy = .lastWins, maximumDepth: Int = 128) {
        self.duplicateKeyPolicy = duplicateKeyPolicy
        self.maximumDepth = maximumDepth
    }

    /// The RFC 7493 (I-JSON) reading, where a repeated key makes the whole document invalid.
    public static let strict = JSONParsingOptions(duplicateKeyPolicy: .reject)
}
