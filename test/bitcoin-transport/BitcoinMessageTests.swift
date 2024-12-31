import Testing
import Foundation
import BitcoinBlockchain
import BitcoinTransport

struct BitcoinMessageTests {

    @Test("Malformed message")
    func malformed() throws {
        let data = Data([0xfa, 0xbf, 0xb5, 0xda, 0x77, 0x74, 0x78, 0x69, 0x64, 0x72, 0x65, 0x6c, 0x61, 0x79, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x5d, 0xf6, 0xe0, 0xe2])
        let parsed = BitcoinMessage(data)
        #expect(parsed != nil)
    }

    @Test("Headers roundtrip")
    func headersRoundtrip() throws {
        let header = TxBlock(previous: .init(count: 32), merkleRoot: .init(count: 32), time: .now, target: 0)
        let header1 = TxBlock(previous: .init(count: 32), merkleRoot: .init(count: 32), time: .now, target: 0, nonce: 1)
        let header2 = TxBlock(previous: .init(count: 32), merkleRoot: .init(count: 32), time: .now, target: 0, nonce: 2)
        let headers = HeadersMessage(items: [header, header1, header2])
        let headersData = headers.data
        let headers2 = HeadersMessage(headersData)
        #expect(headers == headers2)
    }
}
