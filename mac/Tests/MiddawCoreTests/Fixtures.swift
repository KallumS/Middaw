import Foundation

/// The fixtures `tools/make_swift_fixtures.py` writes from the Python reference.
enum Fixtures {
    static let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures")
    static func json(_ name: String) throws -> Any {
        try JSONSerialization.jsonObject(with: Data(contentsOf: folder.appendingPathComponent(name)))
    }
}
