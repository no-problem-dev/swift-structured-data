/// 単一オブジェクト内の重複キー名の処理ポリシー。
///
/// RFC 8259 は重複名の挙動を実装定義としている。このポリシーによって解析時に明示的に選択する。
public enum DuplicateKeyPolicy: Sendable {
    /// 最後の出現を採用（JavaScript 互換のデフォルト）。
    case lastWins
    /// 最初の出現を採用。
    case firstWins
    /// ドキュメントを拒否（I-JSON / RFC 7493 の厳格モード）。
    case reject
    /// 出現順序を保持したまま全て保存する。
    case preserveAll
}

/// 挿入順序を保持する文字列キーコレクション。
///
/// JSON/YAML のオブジェクトは仕様上は順序なしだが、ソース順を保持することで再シリアライズと diff が安定する。
/// ルックアップは最初のマッチを返し、デコーダのキー解決と一致する。
public struct OrderedObject: Sendable, Hashable {
    public private(set) var entries: [(key: String, value: StructuredValue)]

    public init() { entries = [] }

    public init(_ entries: [(key: String, value: StructuredValue)]) {
        self.entries = entries
    }

    /// Swift 辞書から構築する。挿入順は不定（JSON オブジェクトは順序なし）のため、順序が重要な場合は entries イニシャライザを使う。
    public init(_ dictionary: [String: StructuredValue]) {
        self.entries = dictionary.map { ($0.key, $0.value) }
    }

    public var keys: [String] { entries.map(\.key) }
    public var count: Int { entries.count }
    public var isEmpty: Bool { entries.isEmpty }

    public subscript(key: String) -> StructuredValue? {
        get { entries.first { $0.key == key }?.value }
        set {
            if let newValue {
                if let index = entries.firstIndex(where: { $0.key == key }) {
                    entries[index].value = newValue
                } else {
                    entries.append((key, newValue))
                }
            } else {
                entries.removeAll { $0.key == key }
            }
        }
    }

    public mutating func append(key: String, value: StructuredValue) {
        entries.append((key, value))
    }

    /// 指定キーのエントリを削除し、その値を返す。キーが存在しない場合は `nil` を返す。
    @discardableResult
    public mutating func removeValue(forKey key: String) -> StructuredValue? {
        guard let index = entries.firstIndex(where: { $0.key == key }) else { return nil }
        return entries.remove(at: index).value
    }

    /// 標準 Swift 辞書ビュー（挿入順は失われる）。順序が重要な場合は `entries` を使う。
    public var dictionary: [String: StructuredValue] {
        Dictionary(entries.map { ($0.key, $0.value) }, uniquingKeysWith: { _, last in last })
    }

    /// 生エントリから重複キーポリシーを適用してオブジェクトを構築する。
    ///
    /// `nil` を返すのは `policy` が `.reject` かつ重複が存在する場合のみ。
    public static func make(
        from raw: [(key: String, value: StructuredValue)],
        policy: DuplicateKeyPolicy
    ) -> OrderedObject? {
        switch policy {
        case .preserveAll:
            return OrderedObject(raw)
        case .reject:
            var seen = Set<String>()
            for entry in raw where !seen.insert(entry.key).inserted { return nil }
            return OrderedObject(raw)
        case .firstWins, .lastWins:
            var order: [String] = []
            var values: [String: StructuredValue] = [:]
            for entry in raw {
                if values[entry.key] == nil { order.append(entry.key) }
                if policy == .lastWins || values[entry.key] == nil {
                    values[entry.key] = entry.value
                }
            }
            return OrderedObject(order.map { ($0, values[$0]!) })
        }
    }

    /// 順序非依存。JSON/YAML オブジェクトは意味的に順序なしのため、同じ名前/値ペアを持つ 2 つのオブジェクトは順序によらず等しい。
    /// 挿入順はシリアライズのために保持される。
    public static func == (lhs: OrderedObject, rhs: OrderedObject) -> Bool {
        guard lhs.entries.count == rhs.entries.count else { return false }
        var rhsMap: [String: StructuredValue] = [:]
        for entry in rhs.entries { rhsMap[entry.key] = entry.value }
        for entry in lhs.entries where rhsMap[entry.key] != entry.value { return false }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        var accumulator = 0
        for entry in entries {
            var entryHasher = Hasher()
            entryHasher.combine(entry.key)
            entryHasher.combine(entry.value)
            accumulator ^= entryHasher.finalize()
        }
        hasher.combine(accumulator)
    }
}

extension OrderedObject: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, StructuredValue)...) {
        self.init(elements.map { ($0.0, $0.1) })
    }
}

extension OrderedObject: Sequence {
    public func makeIterator() -> Array<(key: String, value: StructuredValue)>.Iterator {
        entries.makeIterator()
    }
}
