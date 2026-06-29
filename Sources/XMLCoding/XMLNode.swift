/// 順序付き属性と順序付き子を持つ XML 要素。
///
/// XML は JSON と異なり順序と属性/子の区別の両方に意味があるため、両方を保持する。
public struct XMLElement: Sendable, Equatable {
    public var name: String
    public var attributes: [XMLAttribute]
    public var children: [XMLNode]

    public init(name: String, attributes: [XMLAttribute] = [], children: [XMLNode] = []) {
        self.name = name
        self.attributes = attributes
        self.children = children
    }

    /// 直接の text/CDATA 子ノードを連結したテキスト。
    public var text: String {
        children.reduce(into: "") { result, node in
            switch node {
            case .text(let value), .cdata(let value): result += value
            default: break
            }
        }
    }

    /// 直接の子要素（`.element` case）のみ抽出した配列。
    public var elements: [XMLElement] {
        children.compactMap { if case .element(let element) = $0 { return element } else { return nil } }
    }

    /// 指定名の属性値を返す。属性が存在しない場合は `nil`。
    public func attribute(_ name: String) -> String? {
        attributes.first { $0.name == name }?.value
    }

    /// 指定名を持つ最初の子要素を返す。存在しない場合は `nil`。
    public func firstElement(named name: String) -> XMLElement? {
        elements.first { $0.name == name }
    }
}

/// XML ノードの種類（要素、テキスト、CDATA、コメント）。
public enum XMLNode: Sendable, Equatable {
    case element(XMLElement)
    case text(String)
    case cdata(String)
    case comment(String)
}

/// XML 属性の名前と値のペア。
public struct XMLAttribute: Sendable, Equatable {
    public var name: String
    public var value: String

    public init(_ name: String, _ value: String) {
        self.name = name
        self.value = value
    }
}
