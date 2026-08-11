/// How Swift values are turned into a tree: key naming and date handling.
public struct EncodingOptions: Sendable {
    /// How to rewrite Swift property names into the document's key names.
    ///
    /// The conversions insert a separator before every uppercase character and lowercase it, with
    /// no notion of an acronym: `userID` becomes `user_i_d`, not `user_id`. Supply a custom
    /// transform when the wire format's spelling matters.
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
    public var dateStrategy: DateCodingStrategy

    public init(keyStrategy: KeyStrategy = .useDefaultKeys, dateStrategy: DateCodingStrategy = .deferredToDate) {
        self.keyStrategy = keyStrategy
        self.dateStrategy = dateStrategy
    }
}
