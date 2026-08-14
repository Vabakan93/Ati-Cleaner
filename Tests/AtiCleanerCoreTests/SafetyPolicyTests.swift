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
}
