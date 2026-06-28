# ``JSONParsing``

JSON parsing and encoding built on the `StructuredDataCore` neutral representation.

## Overview

`JSONParsing` provides the full JSON codec stack for this package. At the top sits ``JSONDecoder``, a thin composition of the lower-level parser and the shared `StructuredDataCore` decoding backbone. Because ``JSONDecoder`` conforms to the `StructuredDecoding` protocol defined in `StructuredDataCore`, you can inject it anywhere a format-agnostic decoder is expected — and later replace it with a `YAMLDecoder` without touching the rest of your code.

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

For cases where you need the intermediate `StructuredValue` directly — for example, to inspect a loosely typed payload before deciding which model to decode into — use ``JSONParser`` instead:

```swift
import JSONParsing

let value = try JSONParser().parse(jsonData)
let kind = value.type.string          // dynamic member access, never throws
let count = value.int("itemCount")    // typed key accessor
```

``StreamingJSONParser`` handles LLM token streams. It accumulates chunks and exposes the best-effort value parsed so far via `snapshot()`, which never throws. Call `finish()` for a strict parse once the stream is complete.

```swift
var streaming = StreamingJSONParser()
for chunk in tokenStream {
    streaming.consume(chunk)
    let partial = streaming.snapshot()   // render partial UI here
}
let final = try streaming.finish()
```

Encoding is the mirror of decoding: ``JSONEncoder`` conforms to the `StructuredEncoding` protocol and uses ``JSONSerializer`` internally.

```swift
let encoder = JSONEncoder()
let data = try encoder.encode(config)
let string = try encoder.string(from: config)
```

## Topics

### Decoding and Encoding

- ``JSONDecoder``
- ``JSONEncoder``

### Parsing and Serialization

- ``JSONParser``
- ``JSONSerializer``
- ``JSONParsingOptions``

### Streaming

- ``StreamingJSONParser``
