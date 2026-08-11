# ``YAMLParsing``

YAML parsing and serialization built on the package's neutral intermediate representation.

## Overview

`YAMLParsing` makes YAML a first-class citizen alongside JSON. ``YAMLDecoder`` conforms to the `StructuredDecoding` protocol from `StructuredDataCore`, so it drops straight into any place that already uses `JSONDecoder` — call sites need no changes.

```swift
import StructuredDataCore
import YAMLParsing

struct AppConfig: Decodable {
    var apiUrl: String
    var retryCount: Int
}

let decoder = YAMLDecoder(
    decodingOptions: DecodingOptions(keyStrategy: .convertFromSnakeCase)
)
let config = try decoder.decode(AppConfig.self, from: yamlData)
```

When you want the raw `StructuredValue` tree rather than a `Decodable` type, use ``YAMLParser`` directly. It reads both single documents and multi-document streams separated by `---` markers.

```swift
import StructuredDataCore
import YAMLParsing

// Single document
let value = try YAMLParser().parse(yamlData)

// Multi-document stream
let documents: [StructuredValue] = try YAMLParser().parseAll(yamlData)
```

The parser covers the JSON-superset subset of the syntax that most external systems emit: block and flow mappings and sequences; plain, single-quoted, double-quoted, literal, and folded scalars; comments; and multi-document streams. Plain scalars are resolved with the YAML 1.2 Core schema, which — unlike YAML 1.1 — leaves `yes`, `no`, `on`, and `off` as strings, so a country code of `NO` stays the string `"NO"`.

Constructs outside that subset throw `ParseError` with a kind of `unsupportedConstruct`, naming what was found. That covers tag (`!`, `!!`), anchor (`&name`), and alias (`*name`) properties in both block and flow context, complex keys introduced by `?`, `%TAG` directives, and `%YAML` directives naming a version other than 1.2. They used to be stripped, with whatever text remained parsed on its own — so `!!str 7` yielded the number `7` and an alias yielded null. Refusing is the honest answer: an alias names a value stated elsewhere in the document, and null is not it. Reach for a full YAML implementation if your documents rely on any of these.

Two gaps are not refused, because neither is distinguishable from ordinary content: a tab used as indentation is not counted, so such a line lands in the wrong parent, and a repeated key is kept rather than resolved.

``YAMLSerializer`` handles the reverse direction. It emits non-empty collections in block style and empty ones in flow style, and quotes any scalar that would not resolve back to the same value — so a string like `"1.0"` survives as a string. Over that same Core subset, `parse(serialize(v)) == v`.

```swift
import YAMLParsing

let yamlString = YAMLSerializer().string(from: structuredValue)
```

## Topics

### Decoding

- ``YAMLDecoder``

### Parsing and Serialization

- ``YAMLParser``
- ``YAMLSerializer``
