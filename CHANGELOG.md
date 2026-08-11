# Changelog

## [Unreleased]

## [3.0.0] - 2026-08-11

### Changed

- **BREAKING** — YAML constructs this parser does not model now throw instead of being silently dropped.
  Tags, anchors, aliases, complex keys, and a `%YAML` directive for anything other than 1.2
  previously produced a value that was not in the document — `!!str 42` came back as the
  number 42, and an alias came back as null. Returning an invented value is worse than
  refusing, because nothing downstream can tell the difference.
- A floating-point literal that overflows `Double` now throws rather than returning infinity.
  Infinity is not what `1e400` rounds to; it means the value is absent.

### Added

- `ParseError` cases naming the unsupported construct, so a caller can report which part of
  the document it could not read.

## [2.0.0] - 2026-07-19

See [GitHub Releases](../../releases) for changes up to and including this version.
