/// Tunables applied while bridging a `StructuredValue` into a `Decodable` type.
public struct DecodingOptions: Sendable {
    /// Maps payload object keys onto Swift property names.
    public enum KeyStrategy: Sendable {
        case useDefaultKeys
        case convertFromSnakeCase
        case convertFromKebabCase
        case custom(@Sendable (String) -> String)

        func convert(_ key: String) -> String {
            switch self {
            case .useDefaultKeys: return key
            case .convertFromSnakeCase: return KeyStrategy.camelCase(from: key, separator: "_")
            case .convertFromKebabCase: return KeyStrategy.camelCase(from: key, separator: "-")
            case .custom(let transform): return transform(key)
            }
        }

        private static func camelCase(from key: String, separator: Character) -> String {
            guard key.contains(separator) else { return key }
            let parts = key.split(separator: separator, omittingEmptySubsequences: false)
            guard let first = parts.first else { return key }
            let leading = String(first)
            let rest = parts.dropFirst().map { part -> String in
                guard let head = part.first else { return "" }
                return head.uppercased() + part.dropFirst()
            }
            return leading + rest.joined()
        }
    }

    public var keyStrategy: KeyStrategy
    public var dateStrategy: DateCodingStrategy

    public init(keyStrategy: KeyStrategy = .useDefaultKeys, dateStrategy: DateCodingStrategy = .deferredToDate) {
        self.keyStrategy = keyStrategy
        self.dateStrategy = dateStrategy
    }
}
