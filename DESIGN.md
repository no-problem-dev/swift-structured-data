# swift-structured-data — 設計

外部システム（LLM API・Web API・設定ファイル）由来の動的な JSON / YAML / XML を、
Swift の型システムへ安全に変換するレイヤー。

## 中心命題: 2 層アーキテクチャ

Foundation の `JSONDecoder` は「パース（正しく読む）」と「型変換（Double に丸める）」を
1 レイヤーで混ぜたために数値バグを抱える（swift-foundation #613/#812, SR-7054/SR-6440）。
本ライブラリは両者を物理的に分離する。

```
Layer 1  Lossless Parse   bytes → StructuredValue   公式適合性スイートで検証
                          ・number は生の十進文字列のまま保持（任意精度を壊さない）
                          ・順序保持・duplicate key ポリシー明示
                ↓ Decoder プロトコル（背骨）
Layer 2  Decode           StructuredValue → Codable / Generics 型
                          ・ここで初めて Int/Double/Decimal を選ぶ
                          ・lossy / default は property wrapper でオプトイン
```

## 規定プロトコル中心のターゲット分離

契約は `StructuredDataCore` に一極集中し、具象パーサは各フォーマットに分散する。

```
StructuredDataCore        外部依存ゼロ。契約 + 背骨 + 中立 DOM
  ├ StructuredValue        format-neutral DOM（null/bool/number/string/array/object）
  ├ StructuredNumber       生十進文字列・遅延変換・正規化等価判定
  ├ OrderedObject          順序保持 + DuplicateKeyPolicy
  ├ DataParser / DataSerializer            パーサ実装者向け seam
  ├ StructuredDecoding / StructuredEncoding 消費者向け seam（Input=Data 固定で existential 可）
  ├ ValueDecoder / ValueEncoder            動的⇄静的の背骨（全フォーマット共有）
  └ Default / LossyArray / LosslessValue   寛容デコードの property wrapper
JSONParsing               → Core のみ依存。RFC 8259 パーサ + Streaming
  (YAMLParsing / XMLParsing は今後同じ形で追加)
```

**依存性逆転の不変条件**: ライブラリは `StructuredDataCore` にのみ依存し
`any StructuredDecoding` を注入で受ける。具象パーサ（`JSONParsing` 等）を import してよいのは
アプリ＝合成ルートのみ。ライブラリの Package.swift に具象パーサが現れたらレビュー赤信号。

データ型の作者には独自プロトコルを一切課さない（標準 `Codable` のみ）。
新しい規定プロトコルはコーダ／パーサ側にだけ置く。

## Swift 技術の配分

| 技術 | 採否 | 用途 |
|---|---|---|
| カスタム `Decoder`/`Encoder` | 採用（背骨） | 動的→静的の標準解。全フォーマット共通化の鍵 |
| `@dynamicMemberLookup`(String) | 採用（糖衣のみ） | `value.user.name` の探索。型安全は別レイヤで担保 |
| generic subscript `[_, as:]` | 採用 | throws 不可を Optional/メソッドで回避 |
| `@propertyWrapper` | 採用 | lossy/default をフィールド単位でオプトイン |
| Macros | 今後（限定） | `@FlexibleCodable`/`@Schema`。型生成には使わない |
| Result Builder | 今後（構築のみ） | リクエストボディ/スキーマの構築 DSL |

## テスト戦略

Layer 1 を公式スイートで固め、Layer 2 は型変換 round-trip と既知エッジで検証する。

| 形式 | スイート | ライセンス | 状態 |
|---|---|---|---|
| JSON | nst/JSONTestSuite | MIT | y_ 95/95・n_ 188/188・i_ 35/35 ✅ |
| JSON | Foundation 数値バグ回帰表 | — | ✅ |
| YAML | yaml/yaml-test-suite (data-2022-01-17) | MIT | Core subset: value-match 85/231 (36%) を計測 ✅ |
| XML | W3C xmlconf | W3C（再配布要確認） | 予定 |

YAML は JSON-superset の Core サブセット（block/flow collection・3 種スカラー・block scalar・
multi-doc・コメント・Norway 修正）を実装済み。フルスペック（anchor/alias・tag・複合キー・
directive）は未対応で、フルスイートに対する value-match を正直に計測している。

## 実装フェーズ

- **Phase 1 — Core + JSON** ✅ 完了（規定プロトコル・背骨・RFC 8259・JSONTestSuite 検証）
- **Phase 2 — 寛容デコード + Streaming** ✅ 完了（Default/LossyArray/LosslessValue・StreamingJSONParser）
- **Phase 6a — YAML 1.2 Core サブセット** ✅ 完了（block/flow・3 スカラー・block scalar・multi-doc・Norway 修正、フルスイート計測）
- **Phase 5 — XML（XMLCoding）** ✅ 完了（well-formed パーサ + ノードモデル + Result Builder 構築 DSL + エスケープ付きシリアライザ）
- **StructuredValue: Codable** ✅ 完了（Foundation コーダ互換・他 Codable 型へ埋め込み可。object 等価は順序非依存・直列化は順序保持）
- **Phase 4 — 既存実装の移行** — 進行中
  - swift-llm-client: `DynamicJSON` を `StructuredValue` ラッパーへ（公開 API 不変・69 tests green）。プロンプトビルダーを `XMLCoding` へ載せ替え（エスケープ獲得）
  - swift-llm-cloud: `OpenAICompatibleJSONValue` → `StructuredValue` typealias（6 プロバイダの基盤・build green）
  - 残: Anthropic/Gemini/OpenAIResponses の各 JSONValue（`.int`/`.double`/`.object(dict)` 構築サイト ~100 箇所の書き換えが必要）
- **Phase 3 — マクロ**（`@FlexibleCodable` + フィールド属性・`@Schema`）— 未着手
- **Phase 4b — swift-api-client**（Date 戦略対応が前提）— 未着手
- **Phase 6b — YAML フルスペック**（anchor/alias・tag・複合キー）— 未着手
- **Phase 7 — Could 機能**（JCS 正規化シリアライズ・パスクエリ）— 未着手

## 差別化ポイント

1. JSON の任意精度数値を壊さない（Foundation が壊す領域）
2. ストリーミング部分デコード（LLM トークン逐次出力の途中状態を抽出）
3. YAML 1.2 Core 厳密準拠は空白地帯（Yams=libYAML は 1.1 寄り）
4. フォーマット非依存の単一 `Decoder` 背骨で JSON/YAML/XML を同一 API に統一
