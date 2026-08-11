[English](./README.md) | 日本語

# swift-structured-data

外から来るデータを Swift に取り込む口を 1 つにする。形式が何であっても。

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%20%7C%20macOS%2014%20%7C%20tvOS%2017%20%7C%20watchOS%2010%20%7C%20visionOS%201%20%7C%20Linux-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

呼ぶ側は値を求めるだけで、それが JSON から来たのか YAML から来たのか XML から来たのかを知る必要がありません。
形式ごとにパーサがあり、どれも同じ中立の値を作り、1 つの `Decoder` バックボーンがその値を型へ変換します。
読む形式を変えるのは 1 箇所の変更で済みます。

## 特徴

- **形式が呼び出し側に漏れない** — `any StructuredDecoding` を注入で受ければ、JSON から YAML への
  差し替えは合成ルート 1 箇所の変更で済みます
- **全フォーマットで単一のバックボーン** — `Decoder`/`Encoder` の実装は 1 つで 3 つのパーサが共有するので、
  3 つの振る舞いが揃います
- **値が道中で変わらない** — 数値は元の文字列のまま運び、具体的な型に求められて初めて変換するので、
  取り込む途中で黙って丸められません
- **入口が 2 つある** — `value.user.name.string` の動的な探索と、型安全な `decode(_:)`
- **寛容なデコードはフィールド単位のオプトイン** — `@Default` / `@LossyArray` / `@LosslessValue`
- **ストリーミング部分デコード** — LLM のトークン逐次出力から途中の状態を取り出せます
- **公式適合性スイートで検証済み** — `nst/JSONTestSuite` を同梱し、`y_` / `n_` / `i_` を網羅しています

## クイックスタート

```swift
import JSONParsing

struct Config: Codable { var retries: Int; var hosts: [String] }

let config = try JSONDecoder().decode(Config.self, from: data)
```

形の分からないペイロードを探索します。欠損したパスは throw ではなく `nil` になります。

```swift
let value = try JSONParser().parse(data)
value.user.name.string          // String?
value.items[0].id.int           // Int?
```

崩れた入力を受けると決めたフィールドだけ、寛容にします。

```swift
struct Settings: Codable {
    @DefaultFalse var verbose: Bool
    @LossyArray var ids: [Int]      // 壊れた要素だけ捨て、デコード全体は失敗させない
    @LosslessValue var port: Int     // 8080 でも "8080" でも受ける
}
```

## ドキュメント

[**API リファレンスとガイド**](https://no-problem-dev.github.io/swift-structured-data/documentation/structureddatacore/) —
[Getting Started](https://no-problem-dev.github.io/swift-structured-data/documentation/structureddatacore/gettingstarted/) と
[Modules](https://no-problem-dev.github.io/swift-structured-data/documentation/structureddatacore/modules/) を含みます。
各パーサが何を受け入れ何を拒むかは Modules にあります。

設計の全体像は [DESIGN.md](./DESIGN.md) を参照してください。

## 導入

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-structured-data.git", from: "3.0.0"),
]
```

必要な product を足します。各フォーマットモジュールは `StructuredDataCore` に依存しています。
`any StructuredDecoding` を注入するなど、その型を直接名指しするターゲットには明示的に足してください。

```swift
.product(name: "StructuredDataCore", package: "swift-structured-data"),
.product(name: "JSONParsing",        package: "swift-structured-data"),
.product(name: "YAMLParsing",        package: "swift-structured-data"),
.product(name: "XMLCoding",          package: "swift-structured-data"),
```

## 動作環境

- iOS 17.0+ / macOS 14.0+ / tvOS 17.0+ / watchOS 10.0+ / visionOS 1.0+
- Linux
- Swift 6.2+

## ライセンス

MIT — [LICENSE](LICENSE) を参照してください。
