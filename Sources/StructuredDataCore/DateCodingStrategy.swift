import Foundation

/// Which wire shape a date takes, chosen once instead of per type.
///
/// A `Date` encodes itself as a `Double` counting seconds from its own reference date, which is
/// almost never what a web or LLM API sends. Setting a strategy here intercepts dates on the scalar
/// path, so the wire format changes without writing `CodingKeys` or a custom `init(from:)` in every
/// model. The default leaves the stock behaviour untouched.
public enum DateCodingStrategy: Sendable {
    /// Leaves dates to their own conformance, which counts seconds from 2001-01-01 UTC.
    case deferredToDate
    /// Whole-second RFC 3339 internet date-time, such as 2024-01-02T03:04:05Z.
    ///
    /// Decoding requires a match, so a payload carrying fractional seconds fails against this.
    case iso8601
    /// RFC 3339 internet date-time with fractional seconds, such as 2024-01-02T03:04:05.123Z.
    ///
    /// Decoding requires the fraction to be present.
    case iso8601WithFractional
    /// A number counting seconds from the 1970 epoch.
    case secondsSince1970
    /// A number counting milliseconds from the 1970 epoch.
    case millisecondsSince1970
    /// Writes fractional-second ISO 8601, and on the way back accepts three shapes rather than one.
    ///
    /// Decoding tries ISO 8601 with fractional seconds, then without, then a bare `yyyy-MM-dd`
    /// read at UTC — the spread of spellings that turn up across LLM and web APIs. It requires a
    /// string, so a numeric timestamp is an error here. Carried over from `swift-api-client`.
    case llmAPIDefault
    /// Supplies both directions yourself, for a format none of the others describes.
    case custom(
        encode: @Sendable (Date) -> StructuredValue,
        decode: @Sendable (StructuredValue) throws -> Date
    )

    /// Whether this strategy replaces the stock date conformance rather than deferring to it.
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
