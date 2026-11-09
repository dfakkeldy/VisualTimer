import Foundation

struct StopwatchLoadResult {
    let records: [StopwatchRecording]
    let unreadableFiles: [String]
}

protocol StopwatchRecordingStorage {
    func load() throws -> StopwatchLoadResult
    func save(_ recording: StopwatchRecording) throws
    func delete(id: UUID) throws
}

/// Device-local records, separate from countdown history and CloudKit. A bad file
/// remains on disk for recovery and is reported without hiding readable records.
final class StopwatchRecordingStore: StopwatchRecordingStorage {
    private let directory: URL
    private let fileManager: FileManager
    private let maximumFileBytes = 2_000_000

    init(directory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.directory = directory ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StopwatchRecordings", isDirectory: true)
    }

    func load() throws -> StopwatchLoadResult {
        guard fileManager.fileExists(atPath: directory.path) else {
            return StopwatchLoadResult(records: [], unreadableFiles: [])
        }
        let urls = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])
        var records: [StopwatchRecording] = []
        var failures: [String] = []
        for url in urls where url.pathExtension == "json" {
            do {
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= maximumFileBytes else { throw StopwatchError.invalidRecording }
                let record = try JSONDecoder().decode(StopwatchRecording.self, from: Data(contentsOf: url))
                try record.validate()
                guard url.deletingPathExtension().lastPathComponent == record.id.uuidString else {
                    throw StopwatchError.invalidRecording
                }
                records.append(record)
            } catch {
                failures.append(url.lastPathComponent)
            }
        }
        records.sort {
            $0.startedAt == $1.startedAt ? $0.id.uuidString < $1.id.uuidString : $0.startedAt > $1.startedAt
        }
        return StopwatchLoadResult(records: records, unreadableFiles: failures.sorted())
    }

    func save(_ recording: StopwatchRecording) throws {
        try recording.validate()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(recording)
        guard data.count <= maximumFileBytes else { throw StopwatchError.invalidRecording }
        try data.write(to: url(for: recording.id), options: [.atomic])
    }

    func delete(id: UUID) throws {
        try fileManager.removeItem(at: url(for: id))
    }

    private func url(for id: UUID) -> URL {
        directory.appendingPathComponent(id.uuidString).appendingPathExtension("json")
    }
}
