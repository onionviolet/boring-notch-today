// Inert dependencies for the standalone workload/lifecycle harness.
import AppKit
import Combine
import EventKit
import Foundation

final class AVCaptureSessionEngine: CameraSessionEngine {
    var eventHandler: (@MainActor @Sendable (CameraSessionEvent) -> Void)?
    var starts = 0
    var stops = 0
    func refresh() {}
    func requestAccess() {}
    func start(selection: CameraSelection) { starts += 1 }
    func stop() { stops += 1 }
    func shutdown() {}
}
struct EventModel: Equatable { let id: String }
struct CalendarModel: Equatable { let id: String; let isReminder: Bool }
protocol CalendarServiceProviding {
    func requestAccess(to: EKEntityType) async throws -> Bool
    func calendars() async -> [CalendarModel]
    func events(from: Date, to: Date, calendars: [String]) async -> [EventModel]
    func setReminderCompleted(reminderID: String, completed: Bool) async
}
class CalendarService: CalendarServiceProviding {
    func requestAccess(to: EKEntityType) async throws -> Bool { false }
    func calendars() async -> [CalendarModel] { [] }
    func events(from: Date, to: Date, calendars: [String]) async -> [EventModel] { [] }
    func setReminderCompleted(reminderID: String, completed: Bool) async {}
}
enum Selection { case all, selected(Set<String>) }
struct FakeKey { static let calendarSelectionState = FakeKey() }
enum Defaults {
    static var value: Selection = .all
    static subscript(key: FakeKey) -> Selection { get { value } set { value = newValue } }
}
struct LoggerStub { func error(_ message: String) {}; func debug(_ message: String) {} }
enum Log { static let shelf = LoggerStub(); static let calendar = LoggerStub() }
struct ShelfItem: Codable, Equatable {
    enum Kind: Codable, Equatable { case file(bookmark: Data), text(String) }
    let id: UUID
    let kind: Kind
    var isTemporary = false
    var identityKey: String { id.uuidString }
    var fileURL: URL? { nil }
    func cleanupStoredData() {}
}
struct Bookmark {
    let data: Data
    func validate() async -> Bool { true }
    func resolve() -> (url: URL?, refreshedData: Data?) { (nil, nil) }
}
enum ShelfDropService { static func items(from: [NSItemProvider]) async -> [ShelfItem] { [] } }

class XCTestCase {}
func XCTAssertEqual<T: Equatable>(_ lhs: T, _ rhs: T, file: StaticString = #filePath, line: UInt = #line) { precondition(lhs == rhs, "Unequal: \(lhs) != \(rhs)", file: file, line: line) }
func XCTAssertTrue(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) { precondition(value, file: file, line: line) }
func XCTAssertFalse(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) { precondition(!value, file: file, line: line) }
func XCTAssertNil<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) { precondition(value == nil, file: file, line: line) }
func XCTAssertNotNil<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) { precondition(value != nil, file: file, line: line) }
