import Foundation

/// 生バイトを中立の中間表現へ解析するプロトコル。
///
/// フォーマットごと（JSON、YAML、XML）に実装する。Layer 1 — ロスレス解析として、フォーマットの公式適合スイートで検証する。ユーザー型への型変換は行わない。
public protocol DataParser: Sendable {
    func parse(_ data: Data) throws -> StructuredValue
}

/// 中立の中間表現をバイト列へシリアライズするプロトコル。
public protocol DataSerializer: Sendable {
    func serialize(_ value: StructuredValue) throws -> Data
}

/// 消費者向けデコードの抽象プロトコル。
///
/// 消費者はこの抽象に依存し、具象デコーダを注入で受け取る。ライブラリが特定フォーマットターゲットを import することなく動作する。
/// `any` 存在型として使えるよう入力を `Data` に固定している。
public protocol StructuredDecoding: Sendable {
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T
}

/// 消費者向けエンコードの抽象プロトコル。
public protocol StructuredEncoding: Sendable {
    func encode<T: Encodable>(_ value: T) throws -> Data
}
