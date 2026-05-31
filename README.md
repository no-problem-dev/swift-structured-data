# swift-structured-data

外部システム由来の動的な構造化データ（JSON ほか）を、Swift の型システムへ安全に変換するレイヤー。
「正しく読む」層と「型へ変換する」層を分離し、数値の精度や順序を失わずに `Codable` へ橋渡しする。

設計の全体像は [DESIGN.md](./DESIGN.md) を参照。

## 特徴

- **任意精度を壊さない数値モデル** — JSON number を生の十進文字列で保持し、要求された型へ遅延変換
- **規定プロトコル中心の依存設計** — 消費者は `any StructuredDecoding` を注入で受け、具象パーサに依存しない
- **フォーマット非依存の単一バックボーン** — カスタム `Decoder`/`Encoder` を 1 度実装し全フォーマットで再利用
- **探索アクセサ** — `value.user.name.string` の動的アクセスと、型安全な `decode(_:)` の二層
- **寛容デコードをフィールド単位でオプトイン** — `@Default` / `@LossyArray` / `@LosslessValue`
- **ストリーミング部分デコード** — LLM のトークン逐次出力から途中状態を抽出
- **公式適合性スイートで検証** — nst/JSONTestSuite を同梱して `y_`/`n_`/`i_` を網羅

## 使い方

### デコード / エンコード

```swift
import JSONParsing

struct Config: Codable { var retries: Int; var hosts: [String] }

let config = try JSONDecoder().decode(Config.self, from: data)
let data = try JSONEncoder().encode(config)
```

### 規定プロトコルへの注入（依存性逆転）

```swift
import StructuredDataCore   // ライブラリは Core にのみ依存

struct APIClient {
    let decoder: any StructuredDecoding
    func parse<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }
}

// 合成ルート（アプリ）だけが具象を選ぶ
let client = APIClient(decoder: JSONDecoder())
```

### 動的な探索

```swift
let value = try JSONParser().parse(data)
value.user.name.string          // String?
value.items[0].id.int           // Int?
value["count", as: Int.self]    // Int?
```

### 寛容デコード

```swift
struct Settings: Codable {
    @DefaultFalse var verbose: Bool
    @DefaultEmptyArray<String> var tags: [String]
    @LossyArray var ids: [Int]          // 壊れた要素を捨てる
    @LosslessValue var port: Int        // "8080" でも 8080 でも受ける
}
```

### ストリーミング

```swift
var parser = StreamingJSONParser()
parser.consume(#"{"name":"Ad"#)
parser.snapshot().name.string    // "Ad"
parser.consume(#"a"}"#)
parser.snapshot().name.string    // "Ada"
```

## モジュール

| モジュール | 役割 |
|---|---|
| `StructuredDataCore` | 規定プロトコル・中立 DOM・`Decoder`/`Encoder` バックボーン・property wrapper |
| `JSONParsing` | RFC 8259 パーサ／シリアライザ・ストリーミング |
| `YAMLParsing` | YAML 1.2 Core サブセットのパーサ（block/flow・block scalar・multi-doc・Norway 修正） |

YAML はフルスペック（anchor/alias・tag・複合キー）未対応。実装状況とテスト計測は
[DESIGN.md](./DESIGN.md) を参照。

## ライセンス

MIT
