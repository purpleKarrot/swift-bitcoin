import XCTest
import Bitcoin

fileprivate let coinbaseTx1 = Transaction(
    version: .v1,
    locktime: .init(0),
    inputs: [
        .init(
            outpoint: .coinbase,
            sequence: .init(0xffffffff),
            script: .init(Data([
                0x05, // OP_PUSHBYTES_5
                0x68, 0x65, 0x6c, 0x6c, 0x6f, // hello
            ]))
        )
    ],
    outputs: [
        .init(
            value: 5_000_000_000, // 50 BTC
            script: .init(Data([
                0x6a, // OP_RETURN
                0x62, 0x79, 0x65 // bye
            ]))
        )
    ])

fileprivate let coinbaseTx2 = Transaction(
    version: .v1,
    locktime: .init(0),
    inputs: [
        .init(
            outpoint: .coinbase,
            sequence: .init(0xffffffff),
            script: .init(Data([
                0x01, // OP_PUSHBYTES_1
                0x00 // 0
            ]))
        )
    ],
    outputs: [
        .init(
            value: 5_000_000_000, // 50 BTC
            script: .init([.constant(1)])
        )
    ])
final class APITests: XCTestCase {

    func testTransactionRoundtrip() throws {
        let data = coinbaseTx1.data
        guard let tx_ = Transaction(data) else {
            XCTFail(); return
        }
        XCTAssertEqual(data, tx_.data)
    }

    func testScript() throws {
        guard let outpoint = coinbaseTx2.outpoint(for: 0) else {
            XCTFail(); return
        }
        // A coinbase transaction
        let tx = Transaction(
            version: .v1,
            locktime: .init(0),
            inputs: [
                .init(
                    outpoint: outpoint,
                    sequence: .init(0),
                    script: .init([.constant(1)])
                )
            ],
            outputs: [
                .init(
                    value: 5_000_000_000, // 50 BTC
                    script: .init(Data([
                        0x6a, // OP_RETURN
                        0x62, 0x79, 0x65 // bye
                    ]))
                )
            ])
        let previousOutputs = [coinbaseTx2.outputs[0]]
        XCTAssert(tx.verify(previousOutputs: previousOutputs))
    }
}