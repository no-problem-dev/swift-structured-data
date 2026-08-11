/// How a parsed tree is turned into Swift types: key naming and date handling.
public struct DecodingOptions: Sendable {
    /// How to rewrite the document's key names before matching them against Swift property names.
    ///
    /// The conversions split on a separator and capitalise each following segment. They are not
    /// reversible and not Foundation-compatible at the edges: a leading separator is dropped and
    /// its segment capitalised, so `_id` matches a property named `Id`, and repeated separators
    /// collapse. An acronym cannot be recovered, since `user_i_d` is what
    /// ``EncodingOptions/KeyStrategy/convertToSnakeCase`` produces for `userID`.
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
