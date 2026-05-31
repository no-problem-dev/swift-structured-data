import Foundation
import Testing
@testable import JSONParsing

/// Drives the parser against the `nst/JSONTestSuite` corpus (MIT).
///
/// `y_*` files must be accepted, `n_*` must be rejected. `i_*` files are
/// implementation-defined; we record our choice without failing.
@Suite(.serialized)
struct JSONConformanceTests {
    static let parsingDirectory: URL = {
        Bundle.module.resourceURL!
            .appendingPathComponent("Suites/JSONTestSuite/test_parsing")
    }()

    static func files(prefix: String) -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: parsingDirectory, includingPropertiesForKeys: nil)) ?? []
        return urls.filter { $0.lastPathComponent.hasPrefix(prefix) && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static let accepted = files(prefix: "y_")
    static let rejected = files(prefix: "n_")
    static let implementationDefined = files(prefix: "i_")

    @Test(arguments: accepted)
    func acceptsValidDocuments(_ url: URL) throws {
        let data = try Data(contentsOf: url)
        #expect(throws: Never.self, "\(url.lastPathComponent) must be accepted") {
            try JSONParser().parse(data)
        }
    }

    @Test(arguments: rejected)
    func rejectsInvalidDocuments(_ url: URL) throws {
        let data = try Data(contentsOf: url)
        #expect(throws: (any Error).self, "\(url.lastPathComponent) must be rejected") {
            try JSONParser().parse(data)
        }
    }

    @Test
    func corpusIsPresent() {
        #expect(Self.accepted.count > 80)
        #expect(Self.rejected.count > 150)
    }

    @Test(arguments: implementationDefined)
    func recordsImplementationDefined(_ url: URL) throws {
        let data = try Data(contentsOf: url)
        _ = try? JSONParser().parse(data)
    }
}
