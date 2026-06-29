/// XML ツリーを宣言的に構築するリザルトビルダー（例: Anthropic スタイルのタグ付きプロンプト）。
///
/// ```swift
/// let prompt = XMLElement("instructions") {
///     XMLElement("role", text: "data analyst")
///     XMLElement("example") {
///         XMLElement("input", text: userText)
///         XMLElement("output", text: expected)
///     }
/// }
/// ```
@resultBuilder
public enum XMLBuilder {
    public static func buildBlock(_ parts: [XMLNode]...) -> [XMLNode] { parts.flatMap { $0 } }
    public static func buildExpression(_ element: XMLElement) -> [XMLNode] { [.element(element)] }
    public static func buildExpression(_ node: XMLNode) -> [XMLNode] { [node] }
    public static func buildExpression(_ text: String) -> [XMLNode] { [.text(text)] }
    public static func buildExpression(_ nodes: [XMLNode]) -> [XMLNode] { nodes }
    public static func buildOptional(_ part: [XMLNode]?) -> [XMLNode] { part ?? [] }
    public static func buildEither(first part: [XMLNode]) -> [XMLNode] { part }
    public static func buildEither(second part: [XMLNode]) -> [XMLNode] { part }
    public static func buildArray(_ parts: [[XMLNode]]) -> [XMLNode] { parts.flatMap { $0 } }
    public static func buildLimitedAvailability(_ part: [XMLNode]) -> [XMLNode] { part }
}

extension XMLElement {
    public init(_ name: String, attributes: [XMLAttribute] = [], @XMLBuilder content: () -> [XMLNode]) {
        self.init(name: name, attributes: attributes, children: content())
    }

    public init(_ name: String, text: String, attributes: [XMLAttribute] = []) {
        self.init(name: name, attributes: attributes, children: text.isEmpty ? [] : [.text(text)])
    }

    /// 指定オプションでこの要素を文字列へシリアライズする。
    public func rendered(options: XMLSerializer.Options = .init()) -> String {
        XMLSerializer(options: options).string(from: self)
    }
}
