# ``XMLCoding``

Codable ブリッジから独立した、XML ドキュメント解析と宣言的ツリー構築。

## Overview

`XMLCoding` は `JSONParsing` や `YAMLParsing` とは意図的に異なるアプローチをとる。XML を `StructuredValue` へ平坦化するのではなく、専用のツリーモデル（``XMLElement`` と ``XMLNode``）を通じてフォーマットの全豊かさを保持する。順序付き属性・混在テキスト/要素コンテンツ・CDATA セクション・コメントをそのまま維持する。

``XMLDocumentParser`` は整形式 XML ドキュメントを ``XMLElement`` ツリーへ解析する。要素、属性、テキスト、CDATA、コメント、処理命令、定義済みおよび数値エンティティ参照を処理する。DTD バリデーションと名前空間解決は対象外で、プレフィックスはそのまま保持される。

```swift
import XMLCoding

let root: XMLElement = try XMLDocumentParser().parse(xmlData)

let version = root.attribute("version")              // "1.2"
let items = root.firstElement(named: "items")        // 最初の <items> 子要素
let allChildren = root.elements                      // 全子要素
let bodyText = root.firstElement(named: "body")?.text  // 連結テキストコンテンツ
```

XML の構築（例: Anthropic スタイルのタグ付きプロンプト）には ``XMLBuilder`` と ``XMLElement`` の便利イニシャライザを組み合わせる。リザルトビルダーは条件分岐・ループ・オプショナルな子をサポートする。

```swift
import XMLCoding

let prompt = XMLElement("prompt") {
    XMLElement("system", text: "You are a data analyst.")
    XMLElement("context") {
        XMLElement("dataset", text: datasetName)
        if includeSchema {
            XMLElement("schema", text: schemaDescription)
        }
    }
    XMLElement("user", text: userQuestion)
}

let xmlString = prompt.rendered()   // デフォルトはプリティプリント
```

``XMLSerializer`` は正しくエスケープを処理する。要素コンテンツの `&`・`<`・`>`、属性値の `"` をエスケープする。任意の ``XMLElement`` ツリーを `String` または `Data` へシリアライズできる。

```swift
let serializer = XMLSerializer(options: .init(prettyPrinted: false))
let compact = serializer.string(from: prompt)
```

## Topics

### ツリーモデル

- ``XMLElement``
- ``XMLNode``
- ``XMLAttribute``

### 解析

- ``XMLDocumentParser``

### 構築とシリアライズ

- ``XMLBuilder``
- ``XMLSerializer``
