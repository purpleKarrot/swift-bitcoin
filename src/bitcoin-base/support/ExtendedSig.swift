import Foundation
import BitcoinCrypto

/// A signature with sighash type extension.
public struct ExtendedSig {

    public init(_ sig: AnySig, _ sighashType: SighashType?) {
        self.sig = sig
        self.sighashType = sighashType
    }

    init?(_ data: Data, skipCheck: Bool = false) {
        guard let last = data.last, let sig = AnySig(data.dropLast()) else {
            return nil
        }
        self.sig = sig
        let sighashType = SighashType(unchecked: last)
        if !skipCheck && !sighashType.isDefined {
            return nil
        }
        self.sighashType = sighashType
    }

    init(schnorrData: Data) throws {
        var sigTmp = schnorrData
        let sighashType: SighashType?
        if sigTmp.count == AnySig.schnorrSignatureExtendedLength, let sighashValue = sigTmp.popLast(), let maybeHashType = SighashType(sighashValue) {
            // If the sig is 65 bytes long, return sig[64] ≠ 0x00 and Verify(q, hashTapSighash(0x00 || SigMsg(sig[64], 0)), sig[0:64]).
            sighashType = maybeHashType
        } else if sigTmp.count == AnySig.schnorrSignatureLength {
            // If the sig is 64 bytes long, return Verify(q, hashTapSighash(0x00 || SigMsg(0x00, 0)), sig), where Verify is defined in BIP340.
            sighashType = SighashType?.none
        } else {
            // Otherwise, fail.
            throw ScriptError.invalidSchnorrSignatureFormat
        }
        guard let sig = AnySig(sigTmp, type: .schnorr) else {
            throw ScriptError.invalidSchnorrSignature
        }
        self.sig = sig
        self.sighashType = sighashType
    }

    public let sig: AnySig
    public let sighashType: SighashType?

    public var data: Data {
        sig.data + sighashType.data
    }
}
