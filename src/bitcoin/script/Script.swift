import Foundation

/// A bitcoin script that hasn't been decoded yet. It may contain invalid operation codes and data as it's backed by a byte array.  For a representation of a ``Script`` that is backed by a list of valid operations  see ``ParsedScript``.
public struct Script: Equatable {

    public static let empty = Self(Data())
    private(set) public var data: Data

    public init(_ data: Data) {
        self.data = data
    }

    public init(_ operations: [ScriptOperation]) {
        self.data = operations.reduce(Data()) { $0 + $1.data }
    }

    init?(prefixedData: Data, version: ScriptVersion = .base) {
        guard let data = Data(varLenData: prefixedData) else {
            return nil
        }
        self.init(data)
    }

    /// Attempts to parse the script and return its assembly representation. Otherwise returns an empty string.
    public func getAsm(version: ScriptVersion) -> String {
        // TODO: When error attempt to return partial decoding. Check how core does this.
        getOperations(version: version)?.map(\.asm).joined(separator: " ") ?? ""
    }

    public var size: Int {
       data.count
    }

    public var isEmpty: Bool {
        data.isEmpty
    }

    public func getOperations(version: ScriptVersion = .base) -> [ScriptOperation]? {
        var data = data
        var operations = [ScriptOperation]()
        while data.count > 0 {
            guard let operation = ScriptOperation(data, version: version) else {
                return nil
            }
            operations.append(operation)
            data = data.dropFirst(operation.size)
        }
        return operations
    }

    public var serialized: Script { self }

    public var prefixedData: Data {
        data.varLenData
    }

    public var prefixedSize: Int {
        data.varLenSize
    }

    // BIP16
    var isPayToScriptHash: Bool {
        if size == 23,
           let operations = getOperations(),
           operations.count == 3,
           operations[0] == .hash160,
           case .pushBytes(_) = operations[1],
           operations[2] == .equal { true } else { false }
    }

    /// BIP141
    var isSegwit: Bool {
        if size >= 3 && size <= 41,
           let operations = getOperations(),
           operations.count == 2,
           case .pushBytes(_) = operations[1]
        {
            if case .constant(_) = operations[0] { true } else { operations[0] == .zero }
        } else {
            false
        }
    }

    /// BIP141
    var witnessProgram: Data {
        precondition(isSegwit)
        guard let operations = getOperations(), case let .pushBytes(data) = operations[1] else {
            preconditionFailure()
        }
        return data
    }

    /// BIP141
    var witnessVersion: Int {
        precondition(isSegwit)
        guard let operations = getOperations() else {
            preconditionFailure()
        }
        return if case let .constant(value) = operations[0] { Int(value) } else if operations[0] == .zero { 0 } else { preconditionFailure() }
    }

    /// Evaluates the script.
    public func run(_ stack: inout [Data], transaction: Transaction, inputIndex: Int, previousOutputs: [Output], tapLeafHash: Data?, version: ScriptVersion = .base, configuration: ScriptConfigurarion) throws {
        var context = ScriptContext(transaction: transaction, inputIndex: inputIndex, previousOutputs: previousOutputs, version: version, configuration: configuration, script: self, tapLeafHash: tapLeafHash)

        while context.programCounter < data.count {
            let startIndex = data.startIndex + context.programCounter
            guard let operation = ScriptOperation(data[startIndex...], version: version) else {
                throw ScriptError.invalidInstruction
            }
            context.decodedOperations.append(operation)
            try operation.execute(stack: &stack, context: &context)

            // BIP342: OP_SUCCESS
            if context.succeedUnconditionally { return }

            context.programCounter += operation.size
        }
        guard context.pendingIfOperations.isEmpty, context.pendingElseOperations == 0 else {
            throw ScriptError.invalidScript
        }
    }

    public func run(_ stack: inout [Data], transaction: Transaction, inputIndex: Int, previousOutputs: [Output], version: ScriptVersion = .base, configuration: ScriptConfigurarion) throws {
        try run(&stack, transaction: transaction, inputIndex: inputIndex, previousOutputs: previousOutputs, tapLeafHash: .none, version: version, configuration: configuration)
    }

    // BIP62
    func checkPushOnly() throws {
        guard let operations = getOperations() else {
            throw ScriptError.unparsableScript
        }
        for op in operations {
            switch op {
            case .oneNegate, .zero, .constant(_), .pushBytes(_), .pushData1(_), .pushData2(_), .pushData4(_): break
            default: throw ScriptError.nonPushOnlyScript
            }
        }
    }
}
