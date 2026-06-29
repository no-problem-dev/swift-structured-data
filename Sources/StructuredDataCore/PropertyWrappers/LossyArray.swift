/// 配列を要素ごとにデコードし、デコードに失敗したエントリを破棄するプロパティラッパー。
///
/// API レスポンスの 1 件の不正要素でペイロード全体を棄却したくない場合に有用。エンコードは透過的。
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
