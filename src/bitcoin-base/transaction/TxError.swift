import Foundation

/// An error while checking a bitcoin transaction.
enum TxError: Error {
    case noInputs,
         noOutputs,
         oversized,
         negativeOutput,
         outputTooLarge,
         totalOutputsTooLarge,
         duplicateInput,
         coinbaseLengthOutOfRange,
         missingOutpoint,
         inputMissingOrSpent,
         prematureCoinbaseSpend,
         inputValuesOutOfRange,
         inputsValueBelowOutput,
         feeOutOfRange,
         futureLockTime
}
