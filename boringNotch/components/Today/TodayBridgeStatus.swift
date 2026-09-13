import Foundation

enum TodayBridgeConnection: Equatable {
    case connected
    case refreshing
    case disconnected
    case stale
    case error
}

struct TodayBridgeStatus: Codable, Equatable {
    enum State: String, Codable { case connected, refreshing, error, disconnected }

    let schemaVersion: Int
    let state: State
    let updatedAt: Date
    let lastPublishAt: Date?
    let refreshRequestId: String?

    static func decodeConnection(from data: Data, at date: Date = Date()) throws -> TodayBridgeConnection {
        guard data.count <= 4 * 1024,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys).isSubset(of: Set(["schemaVersion", "state", "updatedAt", "lastPublishAt", "refreshRequestId"])) else {
            throw TodayPayloadError.invalidText("bridge status")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let status = try decoder.decode(Self.self, from: data)
        guard status.schemaVersion == 1,
              status.updatedAt <= date.addingTimeInterval(5 * 60),
              status.refreshRequestId.map({ UUID(uuidString: $0) != nil }) ?? true else {
            throw TodayPayloadError.invalidText("bridge status")
        }
        if date.timeIntervalSince(status.updatedAt) > 15 { return .stale }
        switch status.state {
        case .connected: return status.refreshRequestId == nil ? .connected : .refreshing
        case .refreshing: return .refreshing
        case .disconnected: return .disconnected
        case .error: return .error
        }
    }
}
