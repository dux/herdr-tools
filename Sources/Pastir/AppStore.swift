import Foundation
import Observation
import PastirCore

@MainActor @Observable final class AppStore {
    private(set) var apps: [CustomApp] = []
    var message: String?
    private let file: CustomAppFile
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init(file: CustomAppFile) { self.file = file }

    func load() async {
        do {
            apps = try await file.load().apps
        } catch {
            message = "Could not load saved apps: \(error.localizedDescription)"
        }
    }

    func add(_ app: CustomApp) {
        apps.append(app)
        scheduleSave()
    }

    func update(_ app: CustomApp) {
        guard let index = apps.firstIndex(where: { $0.id == app.id }) else { return }
        apps[index] = app
        scheduleSave()
    }

    func remove(_ id: UUID) {
        apps.removeAll { $0.id == id }
        scheduleSave()
    }

    func move(from source: IndexSet, to destination: Int) {
        apps.move(fromOffsets: source, toOffset: destination)
        scheduleSave()
    }

    func flush() async -> Bool {
        saveTask?.cancel()
        do {
            try await file.save(snapshot)
            return true
        } catch {
            message = "Could not save apps: \(error.localizedDescription)"
            return false
        }
    }

    private var snapshot: CustomAppFile.Snapshot { CustomAppFile.Snapshot(apps: apps) }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(250))
                try await file.save(snapshot)
            } catch is CancellationError {
                return
            } catch {
                message = "Could not save apps: \(error.localizedDescription)"
            }
        }
    }
}
