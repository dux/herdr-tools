import Foundation
import Observation
import PastirCore

@MainActor @Observable final class ProjectStore {
    private(set) var projects: [Project] = []
    private(set) var selectedID: UUID?
    private(set) var isLoading = true
    var message: String?
    private let file: ProjectFile
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    var selected: Project? { projects.first { $0.id == selectedID } }

    init(file: ProjectFile) { self.file = file }

    func load() async {
        do {
            let snapshot = try await file.load()
            projects = snapshot.projects
            selectedID = projects.first { $0.id == snapshot.selectedID }?.id ?? projects.first?.id
        } catch {
            message = "Could not load saved projects: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func add(_ url: URL) {
        let project = Project(url: url)
        if let existing = projects.first(where: { $0.path == project.path }) {
            select(existing.id)
            return
        }
        projects.append(project)
        selectedID = project.id
        scheduleSave()
    }

    func select(_ id: UUID) {
        selectedID = id
        scheduleSave()
    }

    func remove(_ id: UUID) {
        projects.removeAll { $0.id == id }
        if selectedID == id { selectedID = projects.first?.id }
        scheduleSave()
    }

    func flush() async -> Bool {
        guard !isLoading else { return true }
        saveTask?.cancel()
        do {
            try await file.save(snapshot)
            return true
        } catch {
            message = "Could not save projects: \(error.localizedDescription)"
            return false
        }
    }

    private var snapshot: ProjectFile.Snapshot {
        ProjectFile.Snapshot(projects: projects, selectedID: selectedID)
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(250))
                try await file.save(snapshot)
            } catch is CancellationError {
                return
            } catch {
                message = "Could not save projects: \(error.localizedDescription)"
            }
        }
    }
}
