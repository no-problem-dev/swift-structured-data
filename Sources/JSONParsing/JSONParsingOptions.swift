import StructuredDataCore

/// RFC 8259 パーサの厳格度設定。
public struct JSONParsingOptions: Sendable {
    public var duplicateKeyPolicy: DuplicateKeyPolicy
    /// 最大ネスト深度。スタック枯渇 DoS を防ぐために再帰を制限する。
    public var maximumDepth: Int

    public init(duplicateKeyPolicy: DuplicateKeyPolicy = .lastWins, maximumDepth: Int = 128) {
        self.duplicateKeyPolicy = duplicateKeyPolicy
        self.maximumDepth = maximumDepth
    }

    /// RFC 7493（I-JSON）準拠：重複名を拒否するプリセット。
    public static let strict = JSONParsingOptions(duplicateKeyPolicy: .reject)
}
