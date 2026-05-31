import Foundation
import Testing
import StructuredDataCore
@testable import JSONParsing

struct JSONRoundTripTests {
    @Test(arguments: [
        #"{"a":1,"b":[true,false,null],"c":"x"}"#,
        #"[]"#,
        #"{}"#,
        #"{"nested":{"deep":{"value":9223372036854775808}}}"#,
        #"[1,2.5,-3,1e10]"#,
    ])
    func parseSerializeIsStable(_ json: String) throws {
        let value = try JSONParser().parse(json)
        let serialized = JSONSerializer().string(from: value)
        #expect(serialized == json)
        #expect(try JSONParser().parse(serialized) == value)
    }

    @Test
    func decoderEncoderFacade() throws {
        struct Config: Codable, Equatable { var retries: Int; var hosts: [String] }
        let config = Config(retries: 3, hosts: ["a.io", "b.io"])
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(Config.self, from: data)
        #expect(decoded == config)
    }

    @Test
    func snakeCaseEncodingStrategy() throws {
        struct Row: Codable { var firstName: String }
        let json = try JSONEncoder(encodingOptions: .init(keyStrategy: .convertToSnakeCase))
            .string(from: Row(firstName: "Lin"))
        #expect(json == #"{"first_name":"Lin"}"#)
    }

    @Test
    func prettyPrintedOutput() throws {
        let value = try JSONParser().parse(#"{"a":1}"#)
        let pretty = JSONSerializer(options: .init(prettyPrinted: true)).string(from: value)
        #expect(pretty == "{\n  \"a\": 1\n}")
    }

    @Test
    func injectableAsStructuredDecoding() throws {
        struct Box: Codable, Equatable { var ok: Bool }
        let decoder: any StructuredDecoding = JSONDecoder()
        let box = try decoder.decode(Box.self, from: Data(#"{"ok":true}"#.utf8))
        #expect(box == Box(ok: true))
    }
}
