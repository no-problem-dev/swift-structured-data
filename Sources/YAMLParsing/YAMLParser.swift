import Foundation
import StructuredDataCore

/// Reads the JSON-superset subset of YAML that configuration files actually use, under the 1.2 Core schema.
///
/// This is not a full YAML implementation and does not try to be. What it handles: block and flow
/// mappings and sequences, plain and single- and double-quoted scalars, literal and folded block
/// scalars with their chomping and explicit-indent indicators, comments, and multi-document
/// streams split on `---`.
///
/// What it does not handle is **refused, not guessed at**. Each of these throws a `ParseError`
/// whose kind is `unsupportedConstruct`, because the alternative is handing back a value the
/// document does not say — `!!str 42` as the number 42, an alias as null — with nothing to
/// indicate it:
///
/// - **Tags** (`!`, `!!`, `!<…>`), **anchors** (`&name`) and **aliases** (`*name`), in block and
///   flow context alike. An anchor's own value would survive, but accepting the definition of a
///   name that nothing may then refer to is not worth the exception.
/// - **Complex keys** — a `?` line.
/// - **`%TAG` directives**, which declare shorthands that would go unapplied, and **`%YAML`
///   directives naming any version other than 1.2**, since scalars here resolve under 1.2 Core
///   and 1.1 would make `no` a boolean. `%YAML 1.2` itself agrees with what this does and passes.
///
/// Two gaps are not refused, because neither can be told from ordinary content:
///
/// - **Tabs as indentation.** Only spaces are counted, so a tab-indented line reads as column
///   zero and lands in the wrong parent.
/// - **Repeated keys.** All are kept, with no policy applied.
///
/// Directives, `---` and `...` are recognised line by line, before any block structure is worked
/// out, so a line inside a block scalar that begins with one of them is taken for the real thing.
///
/// Being loud about the unimplemented is not the same as validating: this still accepts plenty of
/// input that a conforming parser must reject, so it remains a reader for documents you control.
/// The exact rate is measured against the official YAML test suite in `ConformanceTests`.
///
/// ``parse(_:)`` returns the first document of a stream and silently discards the rest; use
/// ``parseAll(_:)`` when there may be more than one.
public struct YAMLParser: DataParser {
    public init() {}

    public func parse(_ data: Data) throws -> StructuredValue {
        let documents = try parseAll(data)
        return documents.first ?? .null
    }

    public func parse(_ string: String) throws -> StructuredValue {
        try parse(Data(string.utf8))
    }

    /// Parses every document in a multi-document stream, rather than only the first.
    ///
    /// Documents that hold no content at all are omitted, and a stream that is entirely empty
    /// yields a single null document.
    public func parseAll(_ data: Data) throws -> [StructuredValue] {
        guard let text = String(data: data, encoding: .utf8) else { throw ParseError(.invalidUTF8) }
        var documents: [StructuredValue] = []
        for lines in try YAMLParser.splitDocuments(text) {
            var parser = BlockParser(lines: lines)
            documents.append(try parser.parseRoot())
        }
        return documents
    }

    private static func splitDocuments(_ text: String) throws -> [[String]] {
        var documents: [[String]] = []
        var current: [String] = []
        var sawContent = false
        func flush() {
            if sawContent { documents.append(current) }
            current = []
            sawContent = false
        }
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine.hasSuffix("\r") ? rawLine.dropLast() : rawLine)
            if line.hasPrefix("%") {
                try checkDirective(line)
                continue
            }
            if line == "---" || line.hasPrefix("--- ") || line.hasPrefix("---\t") {
                flush()
                let remainder = line.count > 3 ? "   " + line.dropFirst(3) : ""
                if !remainder.trimmingCharacters(in: .whitespaces).isEmpty {
                    current.append(remainder)
                    sawContent = true
                }
                continue
            }
            if line == "..." || line.hasPrefix("... ") {
                flush()
                continue
            }
            current.append(line)
            if !line.trimmingCharacters(in: .whitespaces).isEmpty { sawContent = true }
        }
        flush()
        return documents.isEmpty ? [[]] : documents
    }

    /// Lets through only the directives that change nothing about how this reads a document.
    ///
    /// `%TAG` declares a shorthand that later nodes use; skipping it would leave those nodes
    /// meaning something else. `%YAML` names the version whose schema resolves the scalars, and
    /// under 1.1 `no` is a boolean rather than the country — the Norway problem, which the whole
    /// Core schema exists to avoid. Only `%YAML 1.2`, which says what this already does, passes.
    ///
    /// Anything else beginning with `%` is a reserved directive, which the spec says to ignore.
    private static func checkDirective(_ line: String) throws {
        let fields = line.split(separator: " ", omittingEmptySubsequences: true)
        guard let name = fields.first else { return }
        if name == "%TAG" {
            throw ParseError(.unsupportedConstruct("%TAG directive"))
        }
        if name == "%YAML" {
            let version = fields.count > 1 ? String(fields[1]) : ""
            guard version == "1.2" else {
                throw ParseError(.unsupportedConstruct("%YAML directive naming version '\(version)'"))
            }
        }
    }
}

/// Line-oriented recursive descent for block context.
private struct BlockParser {
    private var lines: [String]
    private var cursor = 0

    init(lines: [String]) { self.lines = lines }

    mutating func parseRoot() throws -> StructuredValue {
        skipIgnorable()
        guard peek() != nil else { return .null }
        return try parseBlock(indent: indentOfCurrent())
    }

    private mutating func parseBlock(indent: Int) throws -> StructuredValue {
        skipIgnorable()
        guard let line = peek(), indentOf(line) >= indent else { return .null }
        let body = content(line)
        try rejectComplexKey(body)
        if body == "-" || body.hasPrefix("- ") || body.hasPrefix("-\t") {
            return try parseSequence(indent: indentOf(line))
        }
        if keyColon(in: body) != nil {
            return try parseMapping(indent: indentOf(line))
        }
        return try parseScalarNode(indent: indentOf(line))
    }

    private mutating func parseMapping(indent: Int) throws -> StructuredValue {
        var entries: [(key: String, value: StructuredValue)] = []
        while true {
            skipIgnorable()
            guard let line = peek(), indentOf(line) == indent else { break }
            let body = content(line)
            try rejectComplexKey(body)
            guard let colon = keyColon(in: body) else { break }
            let keyText = String(body[..<colon])
            let afterColon = String(body[body.index(after: colon)...])
            advance()
            try rejectNodeProperties(keyText.trimmingCharacters(in: .whitespaces))
            let key = scalarString(keyText)
            let valuePart = afterColon.trimmingCharacters(in: .whitespaces)
            try rejectNodeProperties(valuePart)
            if valuePart.isEmpty {
                entries.append((key, try parseEmptyMappingValue(keyIndent: indent)))
            } else if valuePart.hasPrefix("|") || valuePart.hasPrefix(">") {
                entries.append((key, try parseBlockScalar(header: valuePart, parentIndent: indent)))
            } else if let first = valuePart.first, first == "[" || first == "{" || first == "\"" || first == "'" {
                entries.append((key, try parseInline(valuePart)))
            } else {
                entries.append((key, parsePlainContinuation(initial: valuePart, minIndent: indent + 1)))
            }
        }
        return .object(OrderedObject(entries))
    }

    /// Resolves a mapping value written on following lines. A block sequence may
    /// sit at the same indentation as its key; nested mappings must be deeper.
    private mutating func parseEmptyMappingValue(keyIndent: Int) throws -> StructuredValue {
        skipIgnorable()
        guard let line = peek() else { return .null }
        let lineIndent = indentOf(line)
        let body = content(line)
        if lineIndent == keyIndent, body == "-" || body.hasPrefix("- ") || body.hasPrefix("-\t") {
            return try parseSequence(indent: keyIndent)
        }
        if lineIndent > keyIndent {
            return try parseBlock(indent: lineIndent)
        }
        return .null
    }

    private mutating func parseSequence(indent: Int) throws -> StructuredValue {
        var elements: [StructuredValue] = []
        while true {
            skipIgnorable()
            guard let line = peek(), indentOf(line) == indent else { break }
            let body = content(line)
            guard body == "-" || body.hasPrefix("- ") || body.hasPrefix("-\t") else { break }
            if body == "-" {
                advance()
                elements.append(try parseBlock(indent: indent + 1))
            } else {
                let rest = String(body.dropFirst(2))
                let restColumn = indent + 2
                lines[cursor] = String(repeating: " ", count: restColumn) + rest
                elements.append(try parseBlock(indent: restColumn))
            }
        }
        return .array(elements)
    }

    private mutating func parseScalarNode(indent: Int) throws -> StructuredValue {
        let line = peek()!
        let body = content(line)
        if body.hasPrefix("|") || body.hasPrefix(">") {
            advance()
            return try parseBlockScalar(header: body, parentIndent: indent - 1)
        }
        advance()
        return try parseInline(body)
    }

    private mutating func parseBlockScalar(header: String, parentIndent: Int) throws -> StructuredValue {
        let folded = header.hasPrefix(">")
        let indicators = header.dropFirst()
        var chomp: Character = " "
        var explicitIndent: Int?
        for ch in indicators {
            if ch == "-" || ch == "+" { chomp = ch }
            else if let digit = ch.wholeNumberValue, digit > 0 { explicitIndent = parentIndent + digit }
            else if ch == " " || ch == "#" { break }
        }

        var rawLines: [String] = []
        while let line = peek() {
            if line.trimmingCharacters(in: .whitespaces).isEmpty { rawLines.append(""); advance(); continue }
            if indentOf(line) <= parentIndent { break }
            rawLines.append(line)
            advance()
        }
        while rawLines.last == "" { rawLines.removeLast() ; trailingBlanksRestored += 1 }
        let blockIndent = explicitIndent ?? rawLines.first(where: { !$0.isEmpty }).map(indentOf) ?? parentIndent + 1
        let stripped = rawLines.map { line -> String in
            guard !line.isEmpty else { return "" }
            let dropCount = min(blockIndent, line.prefix(while: { $0 == " " }).count)
            return String(line.dropFirst(dropCount))
        }

        var text: String
        if folded {
            text = foldLines(stripped)
        } else {
            text = stripped.joined(separator: "\n")
        }
        switch chomp {
        case "-": break
        case "+": text += String(repeating: "\n", count: trailingBlanksRestored + 1)
        default: if !text.isEmpty { text += "\n" }
        }
        trailingBlanksRestored = 0
        return .string(text)
    }

    private var trailingBlanksRestored = 0

    private func foldLines(_ lines: [String]) -> String {
        var result = ""
        var previousBlank = true
        for line in lines {
            if line.isEmpty {
                result += "\n"
                previousBlank = true
            } else {
                if !previousBlank { result += " " }
                result += line
                previousBlank = false
            }
        }
        return result
    }

    /// Refuses a node that carries a tag (`!`, `!!`, `!<…>`), an anchor (`&name`) or an alias
    /// (`*name`), none of which this subset resolves.
    ///
    /// Dropping them and reading what is left is the tempting alternative, and it is how this used
    /// to work: `!!str 42` came back as the number 42, and `*base` — a reference to a value
    /// defined elsewhere — came back as null. Both are answers the document never gave, and
    /// nothing in the result marks them.
    ///
    /// None of the three characters can begin a plain scalar in YAML, so there is no valid input
    /// this turns away by mistake.
    private func rejectNodeProperties(_ text: String) throws {
        guard let first = text.first else { return }
        let kind: String
        switch first {
        case "!": kind = "tag"
        case "&": kind = "anchor"
        case "*": kind = "alias"
        default: return
        }
        let token = text.prefix(while: { $0 != " " && $0 != "\t" })
        throw ParseError(.unsupportedConstruct("\(kind) '\(token)'"))
    }

    /// Refuses an explicit key, which this reads as an ordinary scalar and so gets wrong.
    ///
    /// `? [a, b]` on one line and `: value` on the next is a mapping whose key is a sequence.
    /// Read line by line the `?` line looks like a plain scalar and the `: value` line like an
    /// entry with an empty key, which is a different document altogether.
    private func rejectComplexKey(_ body: String) throws {
        guard body == "?" || body.hasPrefix("? ") || body.hasPrefix("?\t") else { return }
        throw ParseError(.unsupportedConstruct("explicit key '?'"))
    }

    /// Gathers a plain scalar that folds across more-indented continuation lines
    /// (`a: b` then `   c` → `"b c"`), then resolves it with the Core schema.
    private mutating func parsePlainContinuation(initial: String, minIndent: Int) -> StructuredValue {
        var collected = [stripComment(initial).trimmingCharacters(in: .whitespaces)]
        while let line = peek() {
            if line.trimmingCharacters(in: .whitespaces).isEmpty { collected.append(""); advance(); continue }
            guard indentOf(line) >= minIndent else { break }
            collected.append(stripComment(content(line)).trimmingCharacters(in: .whitespaces))
            advance()
        }
        while collected.last == "" { collected.removeLast() }
        return YAMLScalarResolver.resolve(foldLines(collected))
    }

    private mutating func parseInline(_ text: String) throws -> StructuredValue {
        let trimmed = stripComment(text).trimmingCharacters(in: .whitespaces)
        try rejectNodeProperties(trimmed)
        guard let first = trimmed.first else { return .null }
        if first == "[" || first == "{" || first == "\"" || first == "'" {
            var scanner = YAMLFlowScanner(trimmed)
            return try scanner.parseDocument()
        }
        return YAMLScalarResolver.resolve(trimmed)
    }

    private func scalarString(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.count >= 2,
           (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) || (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            var scanner = YAMLFlowScanner(trimmed)
            if let value = try? scanner.parseDocument(), case .string(let string) = value {
                return string
            }
        }
        return trimmed
    }

    private func stripComment(_ text: String) -> String {
        var inSingle = false, inDouble = false
        let chars = Array(text)
        for i in chars.indices {
            let ch = chars[i]
            if ch == "'" && !inDouble { inSingle.toggle() }
            else if ch == "\"" && !inSingle { inDouble.toggle() }
            else if ch == "#" && !inSingle && !inDouble {
                if i == 0 || chars[i - 1] == " " || chars[i - 1] == "\t" {
                    return String(chars[..<i])
                }
            }
        }
        return text
    }

    // MARK: Line helpers

    private func peek() -> String? { cursor < lines.count ? lines[cursor] : nil }
    private mutating func advance() { cursor += 1 }

    private mutating func skipIgnorable() {
        while let line = peek() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { advance() } else { break }
        }
    }

    private func indentOfCurrent() -> Int { peek().map(indentOf) ?? 0 }
    private func indentOf(_ line: String) -> Int { line.prefix(while: { $0 == " " }).count }
    private func content(_ line: String) -> String { String(line.drop(while: { $0 == " " })) }

    /// Index of the `:` separating a mapping key from its value, ignoring
    /// colons inside quotes or flow collections.
    private func keyColon(in body: String) -> String.Index? {
        var inSingle = false, inDouble = false, depth = 0
        var index = body.startIndex
        while index < body.endIndex {
            let ch = body[index]
            if ch == "'" && !inDouble { inSingle.toggle() }
            else if ch == "\"" && !inSingle { inDouble.toggle() }
            else if !inSingle && !inDouble {
                if ch == "[" || ch == "{" { depth += 1 }
                else if ch == "]" || ch == "}" { depth -= 1 }
                else if ch == ":" && depth == 0 {
                    let next = body.index(after: index)
                    if next == body.endIndex || body[next] == " " || body[next] == "\t" {
                        return index
                    }
                }
            }
            index = body.index(after: index)
        }
        return nil
    }
}
