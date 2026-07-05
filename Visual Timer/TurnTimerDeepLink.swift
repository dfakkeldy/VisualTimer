import Foundation

enum TurnTimerDeepLink: Equatable {
    case template(UUID)
    case starter(String)

    init?(url: URL) {
        guard url.scheme == "turntimer" else { return nil }
        let value = url.pathComponents.dropFirst().first
        switch url.host {
        case "template":
            guard let value, let id = UUID(uuidString: value) else { return nil }
            self = .template(id)
        case "starter":
            guard let value, !value.isEmpty else { return nil }
            self = .starter(value)
        default:
            return nil
        }
    }
}
