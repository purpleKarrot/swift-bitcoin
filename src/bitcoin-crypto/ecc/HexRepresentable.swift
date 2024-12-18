//
//  HexRepresented.swift
//  swift-bitcoin
//
//  Created by Daniel Pfeifer on 18.12.2024.
//

import Foundation

public protocol HexRepresentable {
    var data: Data { get }
    init?(_ data: Data)
}

public extension HexRepresentable {
    init?(_ hex: String) {
        guard let data = Data(hex: hex) else { return nil }
        self.init(data)
    }
}

public extension CustomStringConvertible where Self: HexRepresentable {
    var description: String { data.hex }
}

public extension Decodable where Self: HexRepresentable {
    init(from decoder: Decoder) throws {
        let string = try String(from: decoder)
        guard let this = Self(string) else {
            preconditionFailure()
        }
        self = this
    }
}

public extension Encodable where Self: HexRepresentable {
    func encode(to encoder: Encoder) throws {
        try data.hex.encode(to: encoder)
    }
}
