/// Decodes an array element by element and drops the ones that fail, rather than losing the whole payload.
///
/// For a response where one malformed entry should not cost you the other ninety-nine. Encoding is
/// unaffected and writes every element.
///
/// Each element's failure is swallowed, so the result is shorter than the source with nothing
/// saying so — the count is not evidence of how many entries were sent. The array itself is still
/// strict: a value that is not an array throws. A missing key or an explicit null gives an empty
/// array.
@propertyWrapper
public struct LossyArray<Element: Codable & Sendable>: Codable, Sendable {
    public var wrappedValue: [Element]

    public init(wrappedValue: [Element]) {
        self.wrappedValue = wrappedValue
    }

    private struct AnyElement: Decodable {
        let value: Element?
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            value = try? container.decode(Element.self)
        }
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var result: [Element] = []
        while !container.isAtEnd {
            if let element = try container.decode(AnyElement.self).value {
                result.append(element)
            }
        }
        wrappedValue = result
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for element in wrappedValue {
            try container.encode(element)
        }
    }
}

extension LossyArray: Equatable where Element: Equatable {}

public extension KeyedDecodingContainer {
    func decode<Element>(_ type: LossyArray<Element>.Type, forKey key: Key) throws -> LossyArray<Element> {
        try decodeIfPresent(type, forKey: key) ?? LossyArray(wrappedValue: [])
    }
}
