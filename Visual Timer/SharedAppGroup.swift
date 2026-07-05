import Foundation

enum SharedAppGroup {
    static let identifier = "group.Dan.Visual-Timer"

    static func containerURL(fileManager: FileManager = .default) -> URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
