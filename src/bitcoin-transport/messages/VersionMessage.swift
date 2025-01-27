import Foundation
import BitcoinCrypto

struct VersionMessage: Equatable, Sendable {
    init(protocolVersion: ProtocolVersion = .latest, services: ProtocolServices = .all, receiverServices: ProtocolServices? = .none, receiverAddress: IPv6Address? = .none, receiverPort: Int? = .none, transmitterAddress: IPv6Address? = .none, transmitterPort: Int? = .none, nonce: UInt64 = 0, userAgent: String = "/SwiftBitcoin:0.1.0/", startHeight: Int = 0, relay: Bool = true) {
        self.protocolVersion = protocolVersion
        self.services = services
        self.timestamp = Date(timeIntervalSince1970: Date.now.timeIntervalSince1970.rounded(.down))
        self.receiverServices = receiverServices ?? .empty
        self.receiverAddress = receiverAddress ?? .unspecified
        self.receiverPort = receiverPort ?? 0
        self.transmitterServices = services
        self.transmitterAddress = transmitterAddress ?? .unspecified
        self.transmitterPort = transmitterPort ?? 0
        self.nonce = nonce
        self.userAgent = userAgent
        self.startHeight = startHeight
        self.relay = relay
    }
    
    let protocolVersion: ProtocolVersion
    let services: ProtocolServices
    let timestamp: Date
    let receiverServices: ProtocolServices
    let receiverAddress: IPv6Address
    let receiverPort: Int
    let transmitterServices: ProtocolServices
    let transmitterAddress: IPv6Address
    let transmitterPort: Int
    let nonce: UInt64
    let userAgent: String
    let startHeight: Int
    let relay: Bool

    var userAgentData: Data {
        userAgent.data(using: .ascii)!
    }
}

extension VersionMessage {
    init?(_ data: Data) {
        guard data.count >= 85 else { return nil }

        var data = data
        guard let protocolVersion = ProtocolVersion(data) else { return nil }
        self.protocolVersion = protocolVersion
        data = data.dropFirst(ProtocolVersion.size)

        guard let services = ProtocolServices(data) else { return nil }
        self.services = services
        data = data.dropFirst(ProtocolServices.size)

        guard data.count >= MemoryLayout<Int64>.size else { return nil }
        let timestamp = data.withUnsafeBytes {
            $0.loadUnaligned(as: Int64.self)
        }
        self.timestamp = Date(timeIntervalSince1970: TimeInterval(timestamp))
        data = data.dropFirst(MemoryLayout<Int64>.size)

        guard let receiverServices = ProtocolServices(data) else { return nil }
        self.receiverServices = receiverServices
        data = data.dropFirst(ProtocolServices.size)

        let receiverAddress = IPv6Address(data.prefix(16))
        self.receiverAddress = receiverAddress
        data = data.dropFirst(16)

        guard data.count >= MemoryLayout<UInt16>.size else { return nil }
        let reveiverPort = data.withUnsafeBytes {
            $0.loadUnaligned(as: UInt16.self)
        }
        self.receiverPort = Int(reveiverPort.byteSwapped) // bigEndian -> littleEndian
        data = data.dropFirst(MemoryLayout<UInt16>.size)

        guard let transmitterServices = ProtocolServices(data) else { return nil }
        self.transmitterServices = transmitterServices
        data = data.dropFirst(ProtocolServices.size)

        let transmitterAddress = IPv6Address(data.prefix(16))
        self.transmitterAddress = transmitterAddress
        data = data.dropFirst(16)

        guard data.count >= MemoryLayout<UInt16>.size else { return nil }
        let transmitterPort = data.withUnsafeBytes {
            $0.loadUnaligned(as: UInt16.self)
        }
        self.transmitterPort = Int(transmitterPort.byteSwapped)
        data = data.dropFirst(MemoryLayout<UInt16>.size)

        guard data.count >= MemoryLayout<UInt64>.size else { return nil }
        let nonce = data.withUnsafeBytes {
            $0.loadUnaligned(as: UInt64.self)
        }
        self.nonce = nonce
        data = data.dropFirst(MemoryLayout<UInt64>.size)

        guard let userAgentDataLength = data.varInt else { return nil }
        data = data.dropFirst(userAgentDataLength.varIntSize)

        guard data.count >= userAgentDataLength else {
            return nil
        }
        let userAgentData = data.prefix(Int(userAgentDataLength))

        let userAgent = String(decoding: userAgentData, as: Unicode.ASCII.self)
        self.userAgent = userAgent
        data = data.dropFirst(userAgentData.count)

        guard data.count >= MemoryLayout<Int32>.size else { return nil }
        let startHeight = data.withUnsafeBytes {
            $0.loadUnaligned(as: Int32.self)
        }
        self.startHeight = Int(startHeight)
        data = data.dropFirst(MemoryLayout<Int32>.size)

        guard data.count >= MemoryLayout<Bool>.size else { return nil }
        let relay = data.withUnsafeBytes {
            $0.loadUnaligned(as: Bool.self)
        }
        self.relay = relay
        data = data.dropFirst(MemoryLayout<Bool>.size)
    }

    var size: Int {
        85 + VarInt(userAgentData.count).binarySize + userAgentData.count
    }

    var data: Data {
        var ret = Data(count: size)
        var offset = ret.addData(protocolVersion.data)
        offset = ret.addBytes(services.rawValue, at: offset)
        offset = ret.addBytes(Int64(timestamp.timeIntervalSince1970), at: offset)
        offset = ret.addBytes(receiverServices.rawValue, at: offset)
        offset = ret.addData(receiverAddress.rawValue, at: offset)
        offset = ret.addBytes(UInt16(receiverPort).bigEndian, at: offset)
        offset = ret.addBytes(transmitterServices.rawValue, at: offset)
        offset = ret.addData(transmitterAddress.rawValue, at: offset)
        offset = ret.addBytes(UInt16(transmitterPort).bigEndian, at: offset)
        offset = ret.addBytes(nonce, at: offset)
        offset = ret.addData(VarInt(userAgentData.count).binaryData, at: offset)
        offset = ret.addData(userAgentData, at: offset)
        offset = ret.addBytes(Int32(startHeight), at: offset)
        offset = ret.addBytes(relay, at: offset)
        return ret
    }
}
