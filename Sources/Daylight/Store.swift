import AppKit
import Combine
import DaylightCore

@MainActor
final class CountdownStore: ObservableObject {
    @Published private(set) var library: CountdownLibrary { didSet { queueSave() } }
    @Published var errorMessage: String?
    @Published var readFailed = false
    @Published private(set) var saved = true
    private let fileURL: URL
    private var saveTask: Task<Void, Never>?
    private var migrationNeedsBackup = false
    let isTestProfile: Bool
    private let demo: Bool

    var entries: [CountdownEntry] { library.entries }
    var selectedID: UUID? {
        get { library.selectedID }
        set {
            guard let newValue, entries.contains(where: { $0.id == newValue }), newValue != library.selectedID else { return }
            library.selectedID = newValue
        }
    }
    var countdown: Countdown {
        get { library.selected?.countdown ?? Countdown() }
        set { guard let id = selectedID else { return }; update(id) { $0.countdown = newValue } }
    }

    init() {
        demo = ProcessInfo.processInfo.arguments.contains("--demo")
        let override = ProcessInfo.processInfo.environment["DAYLIGHT_DATA_DIR"]
        isTestProfile = demo || override != nil
        let base = override.map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Daylight")
        fileURL = base.appendingPathComponent("countdown.json")
        library = CountdownLibrary()
        if !demo, FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let loaded = try CountdownLibraryFile.read(from: fileURL)
                library = loaded.library
                migrationNeedsBackup = loaded.migrated
            } catch {
                readFailed = true
                errorMessage = "Your saved countdowns couldn’t be opened. The original file is safe. Retry, or start fresh with a backup."
            }
        }
    }

    func entry(_ id: UUID) -> CountdownEntry? { entries.first { $0.id == id } }

    func update(_ id: UUID, _ change: (inout CountdownEntry) -> Void) {
        var next = library
        next.update(id, change)
        if next != library { library = next }
    }

    @discardableResult func add() -> UUID { library.add() }
    func addTimer(_ timer: FocusTimer, title: String) -> UUID? { library.addTimer(timer, title: title) }
    func acknowledgeTimer(_ id: UUID) {
        if library.acknowledgeTimer(id) { saveNow() }
    }
    func duplicateSelected() { if let id = selectedID { library.duplicate(id) } }
    func deleteSelected() {
        guard let id = selectedID else { return }
        library.remove(id)
    }

    func setVisible(_ id: UUID, _ visible: Bool) { update(id) { $0.isVisible = visible } }
    func setAllVisible(_ visible: Bool) {
        var next = library
        for index in next.entries.indices { next.entries[index].isVisible = visible }
        if library != next { library = next }
    }

    private func queueSave() {
        guard !demo, !readFailed else { return }
        saved = false
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        saveTask?.cancel()
        guard !demo, !readFailed else { return }
        do {
            if migrationNeedsBackup {
                try backUpOriginal()
                migrationNeedsBackup = false
            }
            try CountdownLibraryFile.write(library, to: fileURL)
            saved = true; errorMessage = nil
        } catch {
            saved = false
            errorMessage = "Your changes haven’t been saved. Check that your Mac has available storage, then retry."
        }
    }

    func retry() {
        guard readFailed else { saveNow(); return }
        do {
            let loaded = try CountdownLibraryFile.read(from: fileURL)
            readFailed = false
            migrationNeedsBackup = loaded.migrated
            library = loaded.library
            errorMessage = nil
        } catch { /* Preserve the original and keep recovery visible. */ }
    }

    private func backUpOriginal() throws {
        let backup = fileURL.deletingLastPathComponent().appendingPathComponent("countdown-backup-\(UUID().uuidString).json")
        try FileManager.default.copyItem(at: fileURL, to: backup)
    }

    func recoverWithBackup() {
        do {
            try backUpOriginal()
            readFailed = false; migrationNeedsBackup = false
            saveNow()
        } catch {
            errorMessage = "The backup couldn’t be created. Your original file is unchanged. Check folder permissions and retry."
        }
    }
}
