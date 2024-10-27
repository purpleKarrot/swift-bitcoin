import Foundation

public protocol JSONStringConvertible: Encodable, CustomStringConvertible { }

public extension JSONStringConvertible {
    var description: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let value = try! encoder.encode(self)
        return String(data: value, encoding: .utf8)!
    }
}
