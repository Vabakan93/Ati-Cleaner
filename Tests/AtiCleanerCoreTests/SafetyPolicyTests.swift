import XCTest
@testable import AtiCleanerCore

final class SafetyPolicyTests: XCTestCase {
    func testSystemRootsAreBlocked() {
        XCTAssertFalse(SafetyPolicy.canScan("/System"))
        XCTAssertFalse(SafetyPolicy.canScan("/usr/bin"))
    }
    func testUserHomeCanBeScanned() {
        XCTAssertTrue(SafetyPolicy.canScan(FileManager.default.homeDirectoryForCurrentUser.path))
    }
    func testProtectedSubtreeIsSkipped() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertFalse(SafetyPolicy.shouldSkipDescendants(of: home + "/Library"))
        XCTAssertFalse(SafetyPolicy.shouldSkipDescendants(of: home + "/Documents"))
        XCTAssertTrue(SafetyPolicy.shouldSkipDescendants(of: home + "/Library/Mail"))
        XCTAssertTrue(SafetyPolicy.shouldSkipDescendants(of: home + "/Music/Media"))
        XCTAssertTrue(SafetyPolicy.shouldSkipDescendants(of: home + "/Pictures/Photos Library.photoslibrary"))
    }
    func testHomeLibrarySkippedForDuplicates() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertTrue(SafetyPolicy.isHomeLibrary(home + "/Library"))
        XCTAssertTrue(SafetyPolicy.isHomeLibrary(home + "/Library/Caches"))
        XCTAssertFalse(SafetyPolicy.isHomeLibrary(home + "/Documents"))
    }
}
