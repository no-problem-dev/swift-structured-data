import Foundation

/// `Date` と ``StructuredValue`` 間の相互変換方法を制御する。
///
/// `Date` の標準 `Codable` 準拠は `Double`（参照日からの秒数）をエンコードするが、多くの Web/LLM API が使う ISO 8601 文字列とは一致しない。
/// このストラテジーはスカラーパスで `Date` をインターセプトし、`CodingKeys` を書かずにワイヤーフォーマットを選択できるようにする。
/// デフォルトは ``deferredToDate`` のため、オプトインしない限り挙動は変わらない。
public enum DateCodingStrategy: Sendable {
    /// `Date` の標準 `Codable`（`Double`）に委譲する。インターセプトなし。
    case deferredToDate
    /// RFC 3339 / ISO 8601 インターネット日時形式（例: `2024-01-02T03:04:05Z`）。
    case iso8601
    /// 小数秒付き ISO 8601（例: `2024-01-02T03:04:05.123Z`）。
    case iso8601WithFractional
    /// 1970 年起点の秒数を表す JSON 数値。
    case secondsSince1970
    /// 1970 年起点のミリ秒数を表す JSON 数値。
    case millisecondsSince1970
    /// LLM/Web API 向け寛容なデフォルト。小数秒付き ISO 8601 でエンコードし、
    /// デコード時は小数秒あり/なし ISO 8601、次いで `yyyy-MM-dd` にフォールバックする。
    /// 旧 `swift-api-client` の挙動を踏襲。
    case llmAPIDefault
    /// 完全にカスタムなブリッジング。
    case custom(
        encode: @Sendable (Date) -> StructuredValue,
        decode: @Sendable (StructuredValue) throws -> Date
    )

    /// このストラテジーが `Date` の標準 `Codable` 処理を置き換えるかどうか。
    public var interceptsDate: Bool {
        if case .deferredToDate = self { return false }
        return true
    }

    public func encode(_ date: Date) -> StructuredValue {
        switch self {
        case .deferredToDate:
            return .number(StructuredNumber(unchecked: String(date.timeIntervalSinceReferenceDate)))
        case .iso8601:
            return .string(DateCodingStrategy.isoString(from: date, fractional: false))
        case .iso8601WithFractional, .llmAPIDefault:
            return .string(DateCodingStrategy.isoString(from: date, fractional: true))
        case .secondsSince1970:
            return .number(StructuredNumber(unchecked: String(date.timeIntervalSince1970)))
        case .millisecondsSince1970:
            return .number(StructuredNumber(unchecked: String(date.timeIntervalSince1970 * 1000)))
        case .custom(let encode, _):
            return encode(date)
        }
    }

    public func decode(_ value: StructuredValue) throws -> Date {
        switch self {
        case .deferredToDate:
            guard let seconds = value.numberValue?.double, seconds.isFinite else { throw Self.corrupt(value) }
            return Date(timeIntervalSinceReferenceDate: seconds)
        case .iso8601:
            return try Self.parseISO(value, fractional: false)
        case .iso8601WithFractional:
            return try Self.parseISO(value, fractional: true)
        case .secondsSince1970:
            guard let seconds = value.numberValue?.double, seconds.isFinite else { throw Self.corrupt(value) }
            return Date(timeIntervalSince1970: seconds)
        case .millisecondsSince1970:
            guard let ms = value.numberValue?.double, ms.isFinite else { throw Self.corrupt(value) }
            return Date(timeIntervalSince1970: ms / 1000)
        case .llmAPIDefault:
            guard let string = value.stringValue else { throw Self.corrupt(value) }
            if let date = Self.isoDate(from: string, fractional: true) { return date }
            if let date = Self.isoDate(from: string, fractional: false) { return date }
            if let date = Self.dateOnly(from: string) { return date }
            throw Self.corrupt(value)
        case .custom(_, let decode):
            return try decode(value)
        }
    }

    // MARK: Formatting helpers

    private static func isoString(from date: Date, fractional: Bool) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = fractional ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private static func parseISO(_ value: StructuredValue, fractional: Bool) throws -> Date {
        guard let string = value.stringValue, let date = isoDate(from: string, fractional: fractional) else {
            throw corrupt(value)
        }
        return date
    }

    private static func isoDate(from string: String, fractional: Bool) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = fractional ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private static func dateOnly(from string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: string)
    }

    private static func corrupt(_ value: StructuredValue) -> DecodingError {
        DecodingError.dataCorrupted(
            .init(codingPath: [], debugDescription: "Cannot decode Date from \(value.diagnosticTypeName).")
        )
    }
}
