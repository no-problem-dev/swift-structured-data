/// Tunables applied while lowering an `Encodable` value into a `StructuredValue`.
public struct EncodingOptions: Sendable {
    /// Maps Swift property names onto payload object keys.
    public enum KeyStrategy: Sendable {
        case useDefaultKeys
        case convertToSnakeCase
        case convertToKebabCase
        case custom(@Sendable (String) -> String)

        func convert(_ key: String) -> String {
            switch self {
            case .useDefaultKeys: return key
            case .convertToSnakeCase: return KeyStrategy.split(key, joinedBy: "_")
            case .convertToKebabCase: return KeyStrategy.split(key, joinedBy: "-")
            case .custom(let transform): return transform(key)
            }
        }

        private static func split(_ key: String, joinedBy separator: String) -> String {
            var result = ""
            for (offset, character) in key.enumerated() {
                if character.isUppercase {
                    if offset != 0 { result += separator }
                    result += character.lowercased()
                } else {
                    result.append(character)
                }
            }
            return result
        }
    }

    public var keyStrategy: KeyStrategy

    public init(keyStrategy: KeyStrategy = .useDefaultKeys) {
        self.keyStrategy = keyStrategy
    }
}
