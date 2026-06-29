English | [日本語](./README.ja.md)

# swift-structured-data

A safe bridge that converts dynamic structured data from external systems (JSON and more) into Swift's type system.
Separates the "parse correctly" layer from the "convert to types" layer, bridging to `Codable` without losing numeric precision or ordering.

For the full design rationale, see [DESIGN.md](./DESIGN.md).

## Features

- **Precision-preserving number model** — JSON numbers are kept as raw decimal text and converted lazily to the requested type
- **Protocol-centric dependency design** — consumers inject `any StructuredDecoding` and never depend on a concrete parser
- **Single backbone for all formats** — one custom `Decoder`/`Encoder` implementation, reused across every format
- **Two-tier access** — dynamic `value.user.name.string` exploration alongside type-safe `decode(_:)`
- **Opt-in tolerant decoding per field** — `@Default` / `@LossyArray` / `@LosslessValue`
- **Streaming partial decode** — extract in-progress state from an LLM token-by-token output
- **Verified against the official conformance suite** — `nst/JSONTestSuite` bundled, covering `y_` / `n_` / `i_` cases

## Usage

### Decode / Encode

```swift
import JSONParsing

struct Config: Codable { var retries: Int; var hosts: [String] }

let config = try JSONDecoder().decode(Config.self, from: data)
let encoded = try JSONEncoder().encode(config)
```

### Inject a protocol (dependency inversion)

```swift
import StructuredDataCore   // library depends only on Core

struct APIClient {
    let decoder: any StructuredDecoding
    func parse<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }
}

// Only the composition root (app) picks the concrete type
let client = APIClient(decoder: JSONDecoder())
```

### Dynamic exploration

```swift
let value = try JSONParser().parse(data)
value.user.name.string          // String?
value.items[0].id.int           // Int?
value["count", as: Int.self]    // Int?
```

### Tolerant decoding

```swift
struct Settings: Codable {
    @DefaultFalse var verbose: Bool
    @DefaultEmptyArray<String> var tags: [String]
    @LossyArray var ids: [Int]          // discard malformed elements
    @LosslessValue var port: Int        // accepts "8080" or 8080
}
```

### Streaming

```swift
var parser = StreamingJSONParser()
parser.consume(#"{"name":"Ad"#)
parser.snapshot().name.string    // "Ad"
parser.consume(#"a"}"#)
parser.snapshot().name.string    // "Ada"
```

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-structured-data.git", from: "1.4.0"),
],
```

Then add the products you need:

```swift
.product(name: "StructuredDataCore", package: "swift-structured-data"),
.product(name: "JSONParsing",         package: "swift-structured-data"),
.product(name: "YAMLParsing",         package: "swift-structured-data"),
.product(name: "XMLCoding",           package: "swift-structured-data"),
```

## Modules

| Module | Role |
|---|---|
| `StructuredDataCore` | Protocols, neutral DOM, `Decoder`/`Encoder` backbone, property wrappers |
| `JSONParsing` | RFC 8259 parser/serializer, streaming |
| `YAMLParsing` | YAML 1.2 Core subset (block/flow, block scalars, multi-doc, Norway fix) |
| `XMLCoding` | XML tree parsing, declarative builder, correct escaping |

YAML does not support the full spec (anchors/aliases, tags, complex keys). For implementation status and test coverage see [DESIGN.md](./DESIGN.md).

## License

MIT
