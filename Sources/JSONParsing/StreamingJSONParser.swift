import Foundation
import StructuredDataCore

/// チャンク単位で届く JSON（例: LLM トークンストリーム）を蓄積し、その時点での最善解を公開する。
///
/// ``snapshot()`` は開いた構造を寛容に閉じ、末尾の不完全トークンを除去するため、
/// ストリーミング中の UI でも部分オブジェクトを描画できる。
/// ``finish()`` は蓄積バッファ全体を厳格に解析する。
public struct StreamingJSONParser: Sendable {
    private var buffer: [UInt8] = []
    private let maximumDepth: Int

    public init(maximumDepth: Int = 128) {
        self.maximumDepth = maximumDepth
    }

    public mutating func consume(_ chunk: Data) {
        buffer.append(contentsOf: chunk)
    }

    public mutating func consume(_ chunk: String) {
        buffer.append(contentsOf: chunk.utf8)
    }

    /// これまでに受信したバイトから解釈した値。スローしない。
    public func snapshot() -> StructuredValue {
        var scanner = TolerantJSONScanner(bytes: buffer, maximumDepth: maximumDepth)
        return scanner.parse()
    }

    /// 蓄積バッファを完全なドキュメントとして厳格に解析する。
    public func finish() throws -> StructuredValue {
        try JSONParser(options: .init(maximumDepth: maximumDepth)).parse(Data(buffer))
    }
}
