English | [日本語](./README.ja.md)

# swift-structured-data

A safe bridge from dynamic JSON, YAML, and XML into Swift's type system.

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%20%7C%20macOS%2014%20%7C%20tvOS%2017%20%7C%20watchOS%2010%20%7C%20visionOS%201-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

Foundation's `JSONDecoder` mixes parsing with type conversion in a single layer, which is where its
long-standing numeric bugs come from. This package separates the two: a parser produces a neutral
value that has lost nothing, and a shared `Decoder` backbone converts that value to your type on
demand.

## Features

- **Numbers keep their precision** — a JSON number is held as its original decimal text and
  converted only when a concrete type asks for it
- **Consumers depend on a protocol** — inject `any StructuredDecoding` and swapping JSON for YAML is
  a change at the composition root, not at every call site
- **One backbone for every format** — a single custom `Decoder`/`Encoder` implementation, reused by
  all three parsers
- **Two ways in** — dynamic exploration with `value.user.name.string`, or type-safe `decode(_:)`
- **Tolerant decoding is opt-in, per field** — `@Default`, `@LossyArray`, `@LosslessValue`
- **Streaming partial decode** — read in-progress state out of a token-by-token LLM response
- **Checked against the official conformance suite** — `nst/JSONTestSuite` is bundled, covering the
  `y_`, `n_`, and `i_` cases

## Quick Start

```swift
import JSONParsing

struct Config: Codable { var retries: Int; var hosts: [String] }

let config = try JSONDecoder().decode(Config.self, from: data)
```

Explore a payload whose shape you do not know yet — missing paths yield `nil` rather than throwing:

```swift
let value = try JSONParser().parse(data)
value.user.name.string          // String?
value.items[0].id.int           // Int?
```

Or accept messy input on the fields where you have decided to:

```swift
struct Settings: Codable {
    @DefaultFalse var verbose: Bool
    @LossyArray var ids: [Int]      // drop malformed elements instead of failing the whole decode
    @LosslessValue var port: Int     // accepts "8080" as well as 8080
}
```

## Documentation

[**API reference and guides**](https://no-problem-dev.github.io/swift-structured-data/documentation/structureddatacore/) —
including [Getting Started](https://no-problem-dev.github.io/swift-structured-data/documentation/structureddatacore/gettingstarted/)
and [Modules](https://no-problem-dev.github.io/swift-structured-data/documentation/structureddatacore/modules/),
which covers what each parser accepts and rejects.

The design rationale, in Japanese, is in [DESIGN.md](./DESIGN.md).

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-structured-data.git", from: "2.0.0"),
]
```

Add the products you need. Each format module depends on `StructuredDataCore`; add it explicitly to
any target that names its types directly, such as one that injects `any StructuredDecoding`:

```swift
.product(name: "StructuredDataCore", package: "swift-structured-data"),
.product(name: "JSONParsing",        package: "swift-structured-data"),
.product(name: "YAMLParsing",        package: "swift-structured-data"),
.product(name: "XMLCoding",          package: "swift-structured-data"),
```

## Requirements

- iOS 17.0+ / macOS 14.0+ / tvOS 17.0+ / watchOS 10.0+ / visionOS 1.0+
- Swift 6.2+

## License

MIT — see [LICENSE](LICENSE).
