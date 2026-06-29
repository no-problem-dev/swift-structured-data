# ``JSONParsing``

`StructuredDataCore` の中立表現上に構築した JSON 解析・エンコードモジュール。

## Overview

`JSONParsing` はこのパッケージの完全な JSON コーデックスタックを提供する。最上位に位置する ``JSONDecoder`` は、低レベルパーサと `StructuredDataCore` の共有デコードバックボーンの薄い合成体。``JSONDecoder`` は `StructuredDataCore` が定義する `StructuredDecoding` プロトコルに準拠しているため、フォーマット非依存なデコーダが期待される箇所に注入でき、後から `YAMLDecoder` へ差し替えてもコードの残りは変更不要。

```swift
import JSONParsing

struct Config: Decodable {
    var host: String
    var port: Int
    var debug: Bool
}

let decoder = JSONDecoder(
    decodingOptions: .init(keyStrategy: .convertFromSnakeCase)
)
let config = try decoder.decode(Config.self, from: jsonData)
```

どのモデルにデコードするか決める前に緩く型付けされたペイロードを検査したい場合など、中間表現 `StructuredValue` を直接必要とする場合は ``JSONParser`` を使う。

```swift
import JSONParsing

let value = try JSONParser().parse(jsonData)
let kind = value.type.string          // 動的メンバーアクセス、スローしない
let count = value.int("itemCount")    // 型付きキーアクセサ
```

``StreamingJSONParser`` は LLM トークンストリームを処理する。チャンクを蓄積し、`snapshot()` でその時点での最善解をスローせずに公開する。ストリームが完了したら `finish()` で厳格な解析を行う。

```swift
var streaming = StreamingJSONParser()
for chunk in tokenStream {
    streaming.consume(chunk)
    let partial = streaming.snapshot()   // ここで部分的な UI を描画する
}
let final = try streaming.finish()
```

エンコードはデコードの鏡像。``JSONEncoder`` は `StructuredEncoding` プロトコルに準拠し、内部で ``JSONSerializer`` を使う。

```swift
let encoder = JSONEncoder()
let data = try encoder.encode(config)
let string = try encoder.string(from: config)
```

## Topics

### デコードとエンコード

- ``JSONDecoder``
- ``JSONEncoder``

### 解析とシリアライズ

- ``JSONParser``
- ``JSONSerializer``
- ``JSONParsingOptions``

### ストリーミング

- ``StreamingJSONParser``
