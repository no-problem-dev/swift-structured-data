import Foundation

/// ``XMLElement`` ツリーをテキストへシリアライズし、コンテンツを正しくエスケープする。
///
/// テキストは `&`・`<`・`>` をエスケープし、属性値ではさらに `"` をエスケープする。
/// 手書きのプロンプトビルダーで見落とされていたエスケープ処理を提供する。
public struct XMLSerializer: Sendable {
    /// シリアライズ動作を制御するオプション。
    public struct Options: Sendable {
        /// インデントと改行を使って出力を整形するかどうか。
        ///
        /// `false` の場合は空白を一切付与せずにシリアライズする。
        public var prettyPrinted: Bool
        /// `prettyPrinted` が `true` のとき、各ネストレベルに付与するインデント文字列。
        public var indent: String

        /// オプションを作成する。
        ///
        /// - Parameters:
        ///   - prettyPrinted: 整形出力を有効にするかどうか。デフォルトは `true`。
        ///   - indent: 整形時のインデント文字列。デフォルトは半角スペース 2 つ。
        public init(prettyPrinted: Bool = true, indent: String = "  ") {
            self.prettyPrinted = prettyPrinted
            self.indent = indent
        }
    }

    public var options: Options

    public init(options: Options = .init()) {
        self.options = options
    }

    /// `XMLElement` ツリーを UTF-8 文字列へシリアライズする。
    ///
    /// - Parameter element: シリアライズするルート要素。
    /// - Returns: エスケープ済みの XML テキスト。
    public func string(from element: XMLElement) -> String {
        var output = ""
        write(element, depth: 0, into: &output)
        return output
    }

    /// `XMLElement` ツリーを UTF-8 エンコード済みバイト列へシリアライズする。
    ///
    /// - Parameter element: シリアライズするルート要素。
    /// - Returns: `string(from:)` の結果を `.utf8` でエンコードしたデータ。
    public func data(from element: XMLElement) -> Data {
        Data(string(from: element).utf8)
    }

    private func write(_ element: XMLElement, depth: Int, into output: inout String) {
        output += "<" + element.name
        for attribute in element.attributes {
            output += " \(attribute.name)=\"\(Self.escapeAttribute(attribute.value))\""
        }
        if element.children.isEmpty {
            output += " />"
            return
        }
        output += ">"

        let onlyText = element.children.allSatisfy { if case .element = $0 { return false } else { return true } }
        if onlyText || !options.prettyPrinted {
            for child in element.children { writeChild(child, depth: depth, inline: true, into: &output) }
        } else {
            for child in element.children {
                newline(depth + 1, into: &output)
                writeChild(child, depth: depth + 1, inline: false, into: &output)
            }
            newline(depth, into: &output)
        }
        output += "</\(element.name)>"
    }

    private func writeChild(_ child: XMLNode, depth: Int, inline: Bool, into output: inout String) {
        switch child {
        case .element(let element): write(element, depth: depth, into: &output)
        case .text(let value): output += Self.escapeText(value)
        case .cdata(let value): output += "<![CDATA[\(value)]]>"
        case .comment(let value): output += "<!--\(value)-->"
        }
    }

    private func newline(_ depth: Int, into output: inout String) {
        guard options.prettyPrinted else { return }
        output += "\n" + String(repeating: options.indent, count: depth)
    }

    /// `&`・`<`・`>` をエスケープし、`text` を XML 要素コンテンツ内で安全にする。
    public static func escapeText(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            default: result.append(character)
            }
        }
        return result
    }

    /// `&`・`<`・`>`・`"` をエスケープし、`text` をダブルクォートで囲まれた XML 属性値内で安全にする。
    public static func escapeAttribute(_ text: String) -> String {
        var result = escapeText(text)
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        return result
    }
}
