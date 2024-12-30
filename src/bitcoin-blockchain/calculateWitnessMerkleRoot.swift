import Foundation
import BitcoinCrypto
import BitcoinBase

func calculateWitnessMerkleRoot(_ txs: [BitcoinTx]) -> Data {
    calculateMerkleRoot(
        [BitcoinTx.coinbaseWitnessID] +
        txs.map(\.witnessID))
}
