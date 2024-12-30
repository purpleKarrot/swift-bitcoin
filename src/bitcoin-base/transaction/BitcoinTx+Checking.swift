import Foundation

/// Transaction checking.
extension BitcoinTx {

    // MARK: - Computed Properties

    private var valueOut: SatoshiAmount {
        outs.reduce(0) { $0 + $1.value }
    }
    
    // MARK: - Instance Methods

    /// This function is called when validating a transaction and it's consensus critical.
    public func check() throws {
        // Basic checks that don't depend on any context
        guard !ins.isEmpty else {
            throw TxError.missingInputs
        }
        guard !outs.isEmpty else {
            throw TxError.missingOutputs
        }

        // Size limits (this doesn't take the witness into account, as that hasn't been checked for malleability)
        guard weight <= Self.maxBlockWeight else {
            throw TxError.oversized
        }

        // Check for negative or overflow output values (see CVE-2010-5139)
        var valueOut: SatoshiAmount = 0
        for out in outs {
            guard out.value >= 0 else {
                throw TxError.negativeOutput
            }
            guard out.value <= Self.maxMoney else {
                throw TxError.outputTooLarge
            }
            valueOut += out.value
            guard valueOut >= 0 && valueOut <= Self.maxMoney else {
                throw TxError.totalOutputsTooLarge
            }
        }

        // Check for duplicate inputs (see CVE-2018-17144)
        // While Consensus::CheckTxIns does check if all inputs of a tx are available, and UpdateCoins marks all inputs
        // of a tx as spent, it does not check if the tx has duplicate ins.
        // Failure to run this check will result in either a crash or an inflation bug, depending on the implementation of
        // the underlying coins database.
        var outpoints = Set<TxOutpoint>()
        for txIn in ins {
            outpoints.insert(txIn.outpoint)
        }
        guard ins.count == outpoints.count else {
            throw TxError.duplicateInput
        }

        if isCoinbase && (ins[0].script.size < 2 || ins[0].script.size > 100) {
            throw TxError.coinbaseLengthOutOfRange
        }
        if !isCoinbase {
            for txIn in ins {
                if txIn.outpoint == TxOutpoint.coinbase {
                    throw TxError.missingOutpoint
                }
            }
        }
    }

    /// This function is called when validating a transaction and it's consensus critical. Needs to be called after ``check()``
    public func checkIns(coins: [TxOutpoint : UnspentOut], spendHeight: Int) throws {
        // are the actual inputs available?
        if !isCoinbase {
            for outpoint in ins.map(\.outpoint) {
                guard coins[outpoint] != .none else {
                    throw TxError.inputMissingOrSpent
                }
            }
        }

        var valueIn = SatoshiAmount(0)
        for txIn in ins {
            let outpoint = txIn.outpoint
            guard let coin = coins[outpoint] else {
                preconditionFailure()
            }
            if coin.isCoinbase && spendHeight - coin.height < Self.coinbaseMaturity {
                throw TxError.prematureCoinbaseSpend
            }
            valueIn += coin.txOut.value
            guard coin.txOut.value >= 0 && coin.txOut.value <= Self.maxMoney,
                  valueIn >= 0 && valueIn <= Self.maxMoney
            else {
                throw TxError.inputValueOutOfRange
            }
        }

        // This is guaranteed by calling Tx.check() before this function.
        precondition(valueOut >= 0 && valueOut <= Self.maxMoney)

        guard valueIn >= valueOut else {
            throw TxError.inputsValueBelowOutput
        }

        let fee = valueIn - valueOut
        guard fee >= 0 && fee <= Self.maxMoney else {
            throw TxError.feeOutOfRange
        }
    }

    public func isFinal(blockHeight: Int?, blockTime: Int?) -> Bool {
        precondition((blockHeight == .none && blockTime != .none) || (blockHeight != .none && blockTime == .none))
        if locktime == .disabled { return true }

        if let blockHeight, let txBlockHeight = locktime.blockHeight, txBlockHeight < blockHeight {
            return true
        } else if let blockTime, let txBlockTime = locktime.secondsSince1970, txBlockTime < blockTime {
            return true
        }

        // Even if tx.nLockTime isn't satisfied by nBlockHeight/nBlockTime, a
        // transaction is still considered final if all inputs' nSequence ==
        // SEQUENCE_FINAL (0xffffffff), in which case nLockTime is ignored.
        //
        // Because of this behavior OP_CHECKLOCKTIMEVERIFY/CheckLockTime() will
        // also check that the spending input's nSequence != SEQUENCE_FINAL,
        // ensuring that an unsatisfied nLockTime value will actually cause
        // IsFinalTx() to return false here:
        return ins.allSatisfy { $0.sequence == .final }
    }

    /// BIP68 - Untested - Entrypoint 1.
    public func checkSequenceLocks(verifyLockTimeSequence: Bool, coins: [TxOutpoint : UnspentOut], chainTip: Int, previousBlockMedianTimePast: Int) throws {
        // CheckSequenceLocks() uses chainActive.Height()+1 to evaluate
        // height based locks because when SequenceLocks() is called within
        // ConnectBlock(), the height of the block *being*
        // evaluated is what is used.
        // Thus if we want to know if a transaction can be part of the
        // *next* block, we need to use one more than chainActive.Height()
        let nextBlockHeight = chainTip + 1
        var heights = [Int]()
        // pcoinsTip contains the UTXO set for chainActive.Tip()
        for txIn in ins {
            guard let coin = coins[txIn.outpoint] else {
                preconditionFailure()
            }
            if coin.height == 0x7FFFFFFF /* MEMPOOL_HEIGHT */ {
                // Assume all mempool transaction confirm in the next block
                heights.append(nextBlockHeight)
            } else {
                heights.append(coin.height)
            }
        }
        let lockPair = calculateSequenceLocks(verifyLockTimeSequence: verifyLockTimeSequence, previousHeights: &heights, blockHeight: nextBlockHeight)
        try evaluateSequenceLocks(blockHeight: nextBlockHeight, previousBlockMedianTimePast: previousBlockMedianTimePast, lockPair: lockPair)
    }

    /// BIP68 - Untested. Entrypoint 2.
    public func sequenceLocks(verifyLockTimeSequence: Bool, previousHeights: inout [Int], blockHeight: Int, previousBlockMedianTimePast: Int) throws {
        try evaluateSequenceLocks(blockHeight: blockHeight, previousBlockMedianTimePast: previousBlockMedianTimePast, lockPair: calculateSequenceLocks(verifyLockTimeSequence: verifyLockTimeSequence, previousHeights: &previousHeights, blockHeight: blockHeight))
    }

    /// BIP68 - Untested
    /// Calculates the block height and previous block's median time past at
    /// which the transaction will be considered final in the context of BIP 68.
    /// Also removes from the vector of input heights any entries which did not
    /// correspond to sequence locked inputs as they do not affect the calculation.
    /// Called from ``sequenceLocks()``.
    func calculateSequenceLocks(verifyLockTimeSequence: Bool, previousHeights: inout [Int], blockHeight: Int) -> (Int, Int) {

        precondition(previousHeights.count == ins.count);

        // Will be set to the equivalent height- and time-based nLockTime
        // values that would be necessary to satisfy all relative lock-
        // time constraints given our view of block chain history.
        // The semantics of nLockTime are the last invalid height/time, so
        // use -1 to have the effect of any height or time being valid.
        var minHeight = -1;
        var minTime = -1;

        // tx.nVersion is signed integer so requires cast to unsigned otherwise
        // we would be doing a signed comparison and half the range of nVersion
        // wouldn't support BIP68.
        let enforceBIP68 = version >= .v2 && verifyLockTimeSequence

        // Do not enforce sequence numbers as a relative lock time
        // unless we have been instructed to
        guard enforceBIP68 else { return (minHeight, minTime) }

        for inIndex in ins.indices {
            let txIn = ins[inIndex]

            // Sequence numbers with the most significant bit set are not
            // treated as relative lock-times, nor are they given any
            // consensus-enforced meaning at this point.
            if txIn.sequence.isLocktimeDisabled {
                // The height of this input is not relevant for sequence locks
                previousHeights[inIndex] = 0
                continue
            }

            let coinHeight = previousHeights[inIndex]

            if let locktimeSeconds = txIn.sequence.locktimeSeconds {
                // NOTE: Subtract 1 to maintain nLockTime semantics
                // BIP68 relative lock times have the semantics of calculating
                // the first block or time at which the transaction would be
                // valid. When calculating the effective block time or height
                // for the entire transaction, we switch to using the
                // semantics of nLockTime which is the last invalid block
                // time or height.  Thus we subtract 1 from the calculated
                // time or height.
                //
                // Time-based relative lock-times are measured from the
                // smallest allowed timestamp of the block containing the
                // txout being spent, which is the median time past of the
                // block prior.
                let coinTime = 0 // TODO: Retrieve the block previous to the coin height `blockHeight.GetAncestor(std::max(nCoinHeight-1, 0))->GetMedianTimePast()`
                minTime = max(minTime, coinTime + locktimeSeconds - 1)
            } else if let locktimeBlocks = txIn.sequence.locktimeBlocks {
                minHeight = max(minHeight, coinHeight + locktimeBlocks - 1)
            }
        }
        return (minHeight, minTime)
    }

    /// BIP68 - Untested. Called by ``BitcoinTx.checkSequenceLocks()`` and ``BitcoinTx.sequenceLocks()``.
    func evaluateSequenceLocks(blockHeight: Int, previousBlockMedianTimePast: Int, lockPair: (Int, Int)) throws {
        if lockPair.0 >= blockHeight || lockPair.1 >= previousBlockMedianTimePast {
            throw TxError.futureLockTime
        }
    }
}
