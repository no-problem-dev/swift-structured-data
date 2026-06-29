/// 型付けされていないドキュメントへの、スロー不可の探索アクセス。
///
/// 型安全なバックボーン上に重ねたシュガー。サブスクリプトはスローせず、欠損パスは `.null` として浮上するため、
/// `value.user.name.string` のようなチェーンを安全に書ける。厳格な変換には ``StructuredValue/decode(_:options:)`` を使う。
/// 動的メンバールックアップは String ベースのためコンパイル時に誤字を検出できない。
extension StructuredValue {
    public subscript(key: String) -> StructuredValue {
        objectValue?[key] ?? .null
    }

    public subscript(index: Int) -> StructuredValue {
        guard let array = arrayValue, array.indices.contains(index) else { return .null }
        return array[index]
    }

    public subscript(dynamicMember member: String) -> StructuredValue {
        objectValue?[member] ?? .null
    }

    /// 子の値をオプショナルでデコードする。欠損または型不一致の場合は `nil` を返す。
    public subscript<T: Decodable>(key: String, as type: T.Type) -> T? {
        try? self[key].decode(type)
    }
}

extension StructuredValue {
    public var string: String? { stringValue }
    public var bool: Bool? { boolValue }
    public var int: Int? { numberValue?.coercedInt }
    public var int64: Int64? { numberValue?.int64 }
    public var double: Double? { numberValue?.double }
    public var array: [StructuredValue]? { arrayValue }
    public var object: OrderedObject? { objectValue }
    public var exists: Bool { !isNull }
}

/// オブジェクト値へのキーベースの型付きアクセサ（数値強制変換付き）。
///
/// `Int` が期待される箇所に `65.0` が届いた場合でも読み取れる（LLM ツール引数によく見られる形式に対応）。
/// 各メソッドはレシーバ（`.object` でなければならない）の `key` を検索し、型付きの抽出を試みる。
/// キーが存在しない、値が `.null`、または型が一致しない場合は `nil` を返す。
extension StructuredValue {
    /// `key` の文字列値。欠損または文字列でない場合は `nil`。
    public func string(_ key: String) -> String? { self[key].stringValue }
    /// `key` の真偽値。欠損または Bool でない場合は `nil`。
    public func bool(_ key: String) -> Bool? { self[key].boolValue }
    /// `key` の整数値。`65.0` のような小数表記を切り捨てて受け付ける。
    public func int(_ key: String) -> Int? { self[key].numberValue?.coercedInt }
    /// `key` の Double 値。欠損または数値でない場合は `nil`。
    public func double(_ key: String) -> Double? { self[key].numberValue?.double }
    /// `key` の配列値。欠損または配列でない場合は `nil`。
    public func array(_ key: String) -> [StructuredValue]? { self[key].arrayValue }
    /// `key` のオブジェクト値。欠損またはオブジェクトでない場合は `nil`。
    public func object(_ key: String) -> OrderedObject? { self[key].objectValue }
    /// `key` の配列の文字列要素。文字列でないエントリを除外する。
    public func stringArray(_ key: String) -> [String]? { self[key].arrayValue?.compactMap(\.stringValue) }
    /// `key` が存在し、値が `.null` でない場合に `true`。
    public func has(_ key: String) -> Bool { objectValue?[key] != nil }
    /// このオブジェクトのキー一覧。値がオブジェクトでない場合は空配列。
    public var keys: [String] { objectValue?.keys ?? [] }
}

extension StructuredNumber {
    /// `Int` として取り出した値。`65.0` のような小数表記を切り捨てて受け付ける。
    public var coercedInt: Int? {
        if let exact = int { return exact }
        let value = double
        return value.isFinite ? Int(value) : nil
    }
}
