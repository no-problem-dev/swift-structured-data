import Foundation

/// Controls how `Date` is bridged to and from a ``StructuredValue``.
///
/// `Date`'s own `Codable` conformance encodes a `Double` (seconds since the
/// reference date), which does not match the ISO 8601 strings most web/LLM APIs
/// use. This strategy intercepts `Date` in the scalar path so callers can pick a
/// wire format without writing `CodingKeys`. Default is ``deferredToDate`` so the
/// behaviour is unchanged unless opted in.
public enum DateCodingStrategy: Sendable {
    /// Defer to `Date`'s standard `Codable` (a `Double`). No interception.
    case deferredToDate
    /// RFC 3339 / ISO 8601 with internet date-time (`2024-01-02T03:04:05Z`).
    case iso8601
    /// ISO 8601 with fractional seconds (`2024-01-02T03:04:05.123Z`).
    case iso8601WithFractional
    /// A JSON number of seconds since 1970.
    case secondsSince1970
    /// A JSON number of milliseconds since 1970.
    case millisecondsSince1970
    /// Lenient default for LLM/web APIs: encodes with fractional ISO 8601;
    /// decodes ISO 8601 (with or without fractional seconds) then falls back to
    /// `yyyy-MM-dd`. Mirrors the historical `swift-api-client` behaviour.
    case llmAPIDefault
    /// Fully custom bridging.
    case custom(
        encode: @Sendable (Date) -> StructuredValue,
        decode: @Sendable (StructuredValue) throws -> Date
    )

    /// Whether this strategy replaces `Date`'s standard `Codable` handling.
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
