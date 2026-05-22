//
//  OnsideErrorTests.swift
//  Neutral Zone TrapTests
//

import Testing
import Foundation
@testable import Neutral_Zone_Trap

@Suite(.tags(.errors))
struct OnsideErrorTests {

    /// Identifikuje wrapping error case, aby testy mohly parametrizovat přes
    /// čtyři enum případy, které sdílejí stejný kontrakt „underlying message
    /// je obsažena v description".
    enum WrappedErrorKind: Sendable, CaseIterable {
        case repositoryFetch, repositorySave, repositoryDelete, sessionImport

        func make(message: String) -> any LocalizedError {
            let underlying = NSError(
                domain: "test", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
            switch self {
            case .repositoryFetch:  return RepositoryError.fetchFailed(underlying: underlying)
            case .repositorySave:   return RepositoryError.saveFailed(underlying: underlying)
            case .repositoryDelete: return RepositoryError.deleteFailed(underlying: underlying)
            case .sessionImport:    return SessionError.importFailed(underlying: underlying)
            }
        }
    }

    @Test(
        "Wrapping errors include the underlying message in their localized description",
        arguments: WrappedErrorKind.allCases
    )
    func wrappedErrorIncludesUnderlying(kind: WrappedErrorKind) throws {
        let message = "underlying-\(kind)"
        let error = kind.make(message: message)

        let description = try #require(error.errorDescription)
        #expect(description.contains(message))
    }

    @Test("GroupSelectionError.conflictingPlayers lists names alphabetically")
    func groupSelectionConflictDescription() throws {
        let error = GroupSelectionError.conflictingPlayers(["Pavel", "Adam", "Marek"])

        let description = try #require(error.errorDescription)
        #expect(description.contains("Adam, Marek, Pavel"))
    }

    @Test("SessionError.noRecordedData explains that recording had no positions")
    func noRecordedDataDescription() throws {
        let description = try #require(SessionError.noRecordedData.errorDescription)

        #expect(description == String(localized: "No positions were recorded."))
    }
}
