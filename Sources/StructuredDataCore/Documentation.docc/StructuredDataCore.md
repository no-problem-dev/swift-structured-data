# ``StructuredDataCore``

フォーマット非依存の構造化データ中間表現と、JSON・YAML・XML ターゲットが共有する Codable ブリッジ。

## Overview

`StructuredDataCore` は全フォーマットパーサが収束する中間表現 ``StructuredValue`` を定義する。このパッケージの全モジュール（`JSONParsing`、`YAMLParsing`、`XMLCoding`）は `StructuredValue` を生成または消費し、`StructuredDataCore` が持つ単一のデコードバックボーンが任意の `Decodable` 型へ変換する。コールサイトで JSON を YAML へ差し替えるには import を 1 行変えるだけでよい。

```swift
import StructuredDataCore
import JSONParsing

// JSON を中立表現へ解析する
let value = try JSONParser().parse(jsonData)

// 値を直接取り出す
let name: String? = value.user.name.string          // 動的メンバーアクセス
let age: Int? = value.int("age")                    // キーベースの型付きアクセサ

// 共有ブリッジ経由で Codable 型へデコードする
struct User: Decodable { var name: String; var age: Int }
let user = try value.decode(User.self)
```

アーキテクチャは 2 層に分かれている。

- **Layer 1 — 解析**: 各フォーマットターゲットが ``DataParser`` を実装し、`Codable` 型変換を一切行わずに `StructuredValue` を生成する。
- **Layer 2 — デコード**: ``StructuredDecoder`` が `DataParser` と共有デコードバックボーンを合成し、``StructuredDecoding`` プロトコルとしてコールサイトへフォーマット非依存の窓口を提供する。

```swift
// フォーマット非依存のデコード — JSONDecoder を YAMLDecoder に差し替えても他は変わらない
func load<T: Decodable>(_ type: T.Type, from data: Data, using decoder: any StructuredDecoding) throws -> T {
    try decoder.decode(type, from: data)
}
```

4 モジュールの責務は以下のとおり。`StructuredDataCore` は中立の中間表現と `Codable` ブリッジを持ち、他の 3 モジュールが唯一共有する依存先。`JSONParsing` は通常の REST/LLM ペイロード向け `JSONDecoder`・`JSONEncoder`、直接 `StructuredValue` を扱う `JSONParser`、トークン単位の LLM 出力向け `StreamingJSONParser` を提供する。`YAMLParsing` は `YAMLDecoder` と `YAMLParser` で YAML 1.2 Core スキーマドキュメントを扱い、ラウンドトリップ用の `YAMLSerializer` も持つ。`XMLCoding` は異なるアプローチをとり、XML を `StructuredValue` へ平坦化するのではなく、`XMLDocumentParser`・`XMLElement`・`XMLBuilder` を通じて要素・属性・混在コンテンツ・CDATA を含む完全な XML ツリーを保持する。

## Topics

### 導入

- <doc:GettingStarted>

### 中間表現

- ``StructuredValue``
- ``StructuredNumber``
- ``OrderedObject``

### 解析・シリアライズのプロトコル

- ``DataParser``
- ``DataSerializer``
- ``StructuredDecoding``
- ``StructuredEncoding``
- ``StructuredDecoder``
- ``StructuredEncoder``

### オプションと設定

- ``DecodingOptions``
- ``EncodingOptions``
- ``DateCodingStrategy``
- ``DuplicateKeyPolicy``

### エラー処理

- ``ParseError``
- ``SourceLocation``

### プロパティラッパー

- ``Default``
- ``DefaultValueProvider``
- ``DefaultProviders``
- ``LosslessValue``
- ``LossyArray``
