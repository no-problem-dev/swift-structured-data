# StructuredDataCore 入門

swift-structured-data をパッケージに追加し、統一 API で JSON・YAML・XML のデコードを始める。

## インストール

`Package.swift` の dependencies に追加する。

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-structured-data.git", from: "1.4.0"),
],
```

次に必要なターゲットを追加する。

```swift
targets: [
    .target(
        name: "MyTarget",
        dependencies: [
            .product(name: "StructuredDataCore", package: "swift-structured-data"),
            .product(name: "JSONParsing",         package: "swift-structured-data"),
            .product(name: "YAMLParsing",         package: "swift-structured-data"),
            .product(name: "XMLCoding",            package: "swift-structured-data"),
        ]
    ),
]
```

必要なターゲットだけを import する。各フォーマットライブラリは独立しており、`StructuredDataCore` は自動的に再エクスポートされる。

## 基本的な使い方

### StructuredValue — 中立の表現

全フォーマットパーサは ``StructuredValue`` を生成する。`.null`、`.bool`、`.number`、`.string`、`.array`、`.object` の 6 ケースを持つ enum。

```swift
import StructuredDataCore

// リテラルで値を構築する
let value: StructuredValue = [
    "name": "Alice",
    "age": 30,
    "active": true,
]

// 動的メンバーアクセス — スローしない。欠損パスは .null を返す
let name = value.name.string          // "Alice"
let city = value.address.city.string  // nil（欠損パス → .null → nil）

// キーベースの型付きアクセサ
let age  = value.int("age")           // 30
let flag = value.bool("active")       // true
```

### JSONDecoder — JSON を Codable へ

```swift
import JSONParsing

struct Article: Decodable {
    var title: String
    var viewCount: Int
}

let decoder = JSONDecoder(
    decodingOptions: .init(keyStrategy: .convertFromSnakeCase)
)
let article = try decoder.decode(Article.self, from: jsonData)
```

`any StructuredDecoding` として使うことでコードをフォーマット非依存に保てる。

```swift
func parse<T: Decodable>(_ type: T.Type, from data: Data, decoder: any StructuredDecoding) throws -> T {
    try decoder.decode(type, from: data)
}
```

### YAMLDecoder — YAML を Codable へ

`YAMLDecoder` は `JSONDecoder` と同じ ``StructuredDecoding`` プロトコルを公開する。JSON デコーダが動く箇所にそのまま差し込める。

```swift
import YAMLParsing

let decoder = YAMLDecoder(
    decodingOptions: .init(keyStrategy: .convertFromSnakeCase)
)
let config = try decoder.decode(AppConfig.self, from: yamlData)
```

`YAMLParser` はマルチドキュメントストリームもサポートする。

```swift
let documents: [StructuredValue] = try YAMLParser().parseAll(yamlData)
```

### XMLDocumentParser + XMLBuilder — XML ツリー

XML は独自のリッチなモデル（`XMLElement` / `XMLNode`）を持ち、属性・混在コンテンツ・CDATA を保持する。

```swift
import XMLCoding

// XML ドキュメントを解析する
let root: XMLElement = try XMLDocumentParser().parse(xmlData)
let version = root.attribute("version")         // 属性の取り出し
let items = root.firstElement(named: "items")   // 最初にマッチした子要素

// リザルトビルダーで XML を構築する（例: Anthropic プロンプトタグ）
let prompt = XMLElement("prompt") {
    XMLElement("system", text: "You are a data analyst.")
    XMLElement("user") {
        XMLElement("question", text: userQuestion)
    }
}
let xmlString = prompt.rendered()
```

XML ツリーを ``StructuredValue`` へ射影して Codable デコードしたい場合は、アプリケーション層で `XMLElement.structuredValue` を実装するか、ツリーを直接走査する。

### パーサの選び方

| 状況 | 使うもの |
|---|---|
| 通常の REST/LLM JSON ペイロード | `JSONDecoder` |
| LLM トークンストリーム（部分 JSON） | `StreamingJSONParser` |
| 設定ファイル | `YAMLDecoder` |
| Anthropic XML プロンプトタグ | `XMLDocumentParser` + `XMLBuilder` |
| 生の中間値 | `JSONParser` / `YAMLParser` 直接 |
| フォーマット非依存デコード | `any StructuredDecoding` |
