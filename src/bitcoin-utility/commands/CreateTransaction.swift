import ArgumentParser
import BitcoinBase
import BitcoinWallet
import Foundation

/// Creates an unsigned raw transaction with the specified inputs and outputs.
struct CreateTx: ParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Creates an unsigned raw transaction with the specified inputs and outputs."
    )

    @Option(name: .shortAndLong, help: "The transaction identifier of each input.")
    var inputTx: [String]

    @Option(name: .shortAndLong, help: "The ouput index of the corresponding input transaction.")
    var outputIndex: [Int]

    @Option(name: .shortAndLong, help: "Address to send to.")
    var address: [String]

    @Option(name: [.customShort("s"), .long], help: "Amount in satoshis (sats) for each of the addresses.")
    var amount: [BitcoinAmount]

    mutating func run() throws {
        guard inputTx.count == outputIndex.count else {
            throw ValidationError("The number of input transactions must match the number of output indices provided.")
        }
        guard address.count == amount.count else {
            throw ValidationError("The number of output addresses must match the number of amounts provided.")
        }
        let outpoints = zip(inputTx, outputIndex)
        let addressesAmounts = zip(address, amount)

        let inputs = try outpoints.map {
            let (inputTx, outputIndex) = $0
            guard let identifier = Data(hex: inputTx) else {
                throw ValidationError("Invalid input transaction hex: \(inputTx)")
            }
            guard identifier.count == BitcoinTx.idLength else {
                throw ValidationError("Invalid transaction identtifier length: \(inputTx)")
            }
            return TxIn(outpoint: .init(tx: identifier, output: outputIndex))
        }

        let outputs = try addressesAmounts.map {
            let (address, amount) = $0
            guard let address = LegacyAddress(address) else {
                throw ValidationError("Invalid address: \(address)")
            }
            return address.output(amount)
        }

        let tx = BitcoinTx(
            inputs: inputs,
            outputs: outputs
        )
        print(tx.data.hex)
    }
}
