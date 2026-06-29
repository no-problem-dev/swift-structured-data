import Foundation
import StructuredDataCore

/// 消費者向けデコードプロトコルへの YAML エントリポイント。
///
/// ``YAMLParser``（Layer 1）と共有デコードバックボーンを合成する。YAML ペイロードが JSON と同じパスで `Codable` 型へデコードされる。
/// コールサイトをフォーマット非依存に保つために `any StructuredDecoding` として注入する。
public struct YAMLDecoder: StructuredDecoding {
    public var decodingOptions: DecodingOptions

    public init(decodingOptions: DecodingOptions = .init()) {
        self.decodingOptions = decodingOptions
    }

    public func value(from data: Data) throws -> StructuredValue {
        try YAMLParser().parse(data)
    }

    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try value(from: data).decode(type, options: decodingOptions)
    }

    public func decode<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
        try decode(type, from: Data(string.utf8))
    }
}
