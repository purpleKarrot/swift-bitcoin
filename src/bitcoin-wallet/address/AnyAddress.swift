import BitcoinBase

/// Type-erased bitcoin address. Use when needing to decode and generate outputs but the type of address being decoded is not known beforehand
public enum AnyAddress: BitcoinAddress {

    case legacy(LegacyAddress), segwit(SegwitAddress), taproot(TaprootAddress)

    public init?(_ address: String) {
        if let a = LegacyAddress(address) { self = .legacy(a) }
        else if let a = SegwitAddress(address) { self = .segwit(a) }
        else if let a = TaprootAddress(address) { self = .taproot(a) }
        else { return nil }
    }

    public func out(_ value: BitcoinBase.SatoshiAmount) -> BitcoinBase.TxOut {
        let address: any BitcoinAddress = switch self {
        case .legacy(let a): a
        case .segwit(let a): a
        case .taproot(let a): a
        }
        return address.out(value)
    }

    public var description: String {
        let address: any BitcoinAddress = switch self {
        case .legacy(let a): a
        case .segwit(let a): a
        case .taproot(let a): a
        }
        return address.description
    }
}
