# ``YAMLParsing``

`StructuredDataCore` の中立表現上に構築した YAML 1.2 Core スキーマ解析・シリアライズモジュール。

## Overview

`YAMLParsing` は YAML をこのパッケージで JSON と同等のファーストクラス市民にする。``YAMLDecoder`` は `StructuredDataCore` の `StructuredDecoding` プロトコルに準拠しているため、`JSONDecoder` が使われている箇所にそのまま差し込める。コールサイトを変更する必要はない。

```swift
import YAMLParsing

struct AppConfig: Decodable {
    var apiUrl: String
    var retryCount: Int
}

let decoder = YAMLDecoder(
    decodingOptions: .init(keyStrategy: .convertFromSnakeCase)
)
let config = try decoder.decode(AppConfig.self, from: yamlData)
```

`Decodable` 型ではなく生の `StructuredValue` ツリーが必要な場合は ``YAMLParser`` を直接使う。`---` マーカーで区切られたシングルドキュメントとマルチドキュメントストリームの両方をサポートする。

```swift
import YAMLParsing

// シングルドキュメント
let value = try YAMLParser().parse(yamlData)

// マルチドキュメントストリーム
let documents: [StructuredValue] = try YAMLParser().parseAll(yamlData)
```

パーサは多くの外部システムが生成する JSON 上位互換の Core サブセットをカバーする。ブロック/フローのマッピングとシーケンス、プレイン・シングルクォート・ダブルクォート・リテラル・フォールドスカラー、コメント、マルチドキュメントストリームに対応。タグ、アンカー/エイリアス、複合キーはプレインテキストとして通過する。

``YAMLSerializer`` は逆変換を担う。非空コレクションはブロックスタイルで出力し、`parse(serialize(v)) == v` を同じ Core サブセット上で保証する。

```swift
import YAMLParsing

let yamlString = YAMLSerializer().string(from: structuredValue)
```

## Topics

### デコード

- ``YAMLDecoder``

### 解析とシリアライズ

- ``YAMLParser``
- ``YAMLSerializer``
