import Foundation

/// A block of transactions.
public struct BlockContext: Equatable, Sendable {

    public enum ValidationStatus: Sendable {
        case header, merkle, full
    }

    // MARK: - Initializers

    public init(height: Int, chainwork: DifficultyTarget, status: ValidationStatus = .header) {
        self.height = height
        self.chainwork = chainwork
        self.status = status
    }

    // MARK: - Instance Properties

    public internal(set) var height: Int
    public internal(set) var chainwork: DifficultyTarget
    public internal(set) var status: ValidationStatus

    // MARK: - Computed Properties

    // MARK: - Instance Methods

    // MARK: - Type Properties

    // MARK: - Type Methods
}
