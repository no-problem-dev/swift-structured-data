// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-structured-data",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "StructuredDataCore", targets: ["StructuredDataCore"]),
        .library(name: "JSONParsing", targets: ["JSONParsing"]),
        .library(name: "YAMLParsing", targets: ["YAMLParsing"]),
        .library(name: "XMLCoding", targets: ["XMLCoding"]),
    ],
    targets: [
        .target(name: "StructuredDataCore"),
        .target(name: "JSONParsing", dependencies: ["StructuredDataCore"]),
        .target(name: "YAMLParsing", dependencies: ["StructuredDataCore"]),
        .target(name: "XMLCoding", dependencies: ["StructuredDataCore"]),

        .testTarget(name: "StructuredDataCoreTests", dependencies: ["StructuredDataCore"]),
        .testTarget(name: "JSONParsingTests", dependencies: ["JSONParsing"]),
        .testTarget(name: "YAMLParsingTests", dependencies: ["YAMLParsing"]),
        .testTarget(name: "XMLCodingTests", dependencies: ["XMLCoding"]),
        .testTarget(
            name: "ConformanceTests",
            dependencies: ["JSONParsing", "YAMLParsing"],
            resources: [.copy("Suites")]
        ),
    ]
)
