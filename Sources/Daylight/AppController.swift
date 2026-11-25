import AppKit
import SwiftUI
import Combine
import DaylightCore

struct DisplayChoice: Identifiable {
    let id: CGDirectDisplayID
    let name: String
}

private let displayReconfigurationCallback: CGDisplayReconfigurationCallBack = { _, flags, context in
    guard let context else { return }
    let controller = Unmanaged<AppController>.fromOpaque(context).takeUnretainedValue()
    DispatchQueue.main.async {
        if flags.contains(.beginConfigurationFlag) {
            controller.beginDisplayReconfiguration()
        } else {
            controller.refreshDisplays()
        }
    }
}

@MainActor
final class AppController: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate, ObservableObject {
    let store: CountdownStore
    private let displaySource: (() -> [WidgetDisplay])?
    let loginItem = LoginItem()
    @Published var arrangementMessage: String?
    var editorWindow: NSWindow?
    private(set) var widgetWindows: [UUID: NSWindow] = [:]
    @Published private(set) var fullScreenIDs: Set<UUID> = []
    @Published var displays: [DisplayChoice] = []
    @Published var timerSetupOpen = false
    @Published private(set) var alarmPlaying = false
    private var alarmSound: NSSound?
    private var timerActivity: NSObjectProtocol?
    private var announcedTimers: Set<UUID> = []
    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    private enum TilePresentation { case normal, raised, lowered }
    private var tilePresentation = TilePresentation.normal
    private var subscription: AnyCancellable?
    private var timer: Timer?
    private var tileHoverTimer: Timer?
    private var terminating = false
    private var restoringFrame = false
    private var placementSaveTasks: [UUID: Task<Void, Never>] = [:]
    private var userPlacementEdits: Set<UUID> = []
    private var displayConfigurationChanging = false
    private var displayRefreshTask: Task<Void, Never>?
    private var displayLayouts = DisplayLayoutSession()
    var widgetFullScreen: Bool { store.selectedID.map { fullScreenIDs.contains($0) } ?? false }

    init(store: CountdownStore = CountdownStore(), displaySource: (() -> [WidgetDisplay])? = nil) {
        self.store = store
        self.displaySource = displaySource
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildMenu()
        buildStatusItem()
        store.updateLibrary { _ = displayLayouts.activate(currentWidgetDisplays(), in: &$0) }
        CGDisplayRegisterReconfigurationCallback(displayReconfigurationCallback, Unmanaged.passUnretained(self).toOpaque())
        refreshDisplays()
        NotificationCenter.default.addObserver(self, selector: #selector(refreshDisplays), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refreshAfterWake), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshAfterWake), name: .NSSystemTimeZoneDidChange, object: nil)
        subscription = store.$library.receive(on: RunLoop.main).sink { [weak self] _ in
            guard let self else { return }
            self.syncWindows(self.store.library)
            self.updateStatus(self.store.library)
            self.refreshTimers()
        }
        let pulse = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in guard let self else { return }; self.refreshTimers(); self.updateStatus(self.store.library) }
        }
        timer = pulse
        RunLoop.main.add(pulse, forMode: .common)
        syncWindows(store.library)
        loginItem.enableForInstalledAppIfNeeded(isTestProfile: store.isTestProfile)
        let firstLaunchKey = "Daylight.HasLaunched.v2"
        if !UserDefaults.standard.bool(forKey: firstLaunchKey) || store.readFailed {
            UserDefaults.standard.set(true, forKey: firstLaunchKey)
            showEditor()
        }
        store.saveNow()
        refreshTimers()
    }

    private func updateTileHoverTimer() {
        guard !widgetWindows.isEmpty else {
            tileHoverTimer?.invalidate(); tileHoverTimer = nil
            return
        }
        guard tileHoverTimer == nil else { return }
        // One shared sampler: native titlebar and SwiftUI child tracking cannot disagree.
        let pulse = Timer(timeInterval: 0.08, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateTileHover() }
        }
        pulse.tolerance = 0.01
        tileHoverTimer = pulse
        RunLoop.main.add(pulse, forMode: .common)
        updateTileHover()
    }

    private func updateTileHover() {
        let pointer = NSEvent.mouseLocation
        let candidates = widgetWindows.values.filter { $0.isVisible && !$0.isMiniaturized && $0.frame.contains(pointer) }
        let hitWindow = candidates.isEmpty ? -1 : NSWindow.windowNumber(at: pointer, belowWindowWithWindowNumber: 0)
        for window in widgetWindows.values {
            (window as? TileWindow)?.setCloseControlHovered(window.windowNumber == hitWindow)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) { loginItem.refresh() }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        for (id, window) in widgetWindows { savePlacement(id, window) }
        terminating = true
        store.saveNow()
        return .terminateNow
    }
    func applicationWillTerminate(_ notification: Notification) {
        CGDisplayRemoveReconfigurationCallback(displayReconfigurationCallback, Unmanaged.passUnretained(self).toOpaque())
        displayRefreshTask?.cancel()
        tileHoverTimer?.invalidate()
        alarmSound?.stop()
        if let timerActivity { ProcessInfo.processInfo.endActivity(timerActivity) }
        store.saveNow()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showEditor(); return true
    }

    @objc func showEditor() {
        if tilePresentation == .raised { tilePresentation = .normal }
        if NSApp.activationPolicy() != .regular { NSApp.setActivationPolicy(.regular) }
        if editorWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 800), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Daylight — Your countdowns"
            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor(Design.canvas)
            window.minSize = NSSize(width: 910, height: 790)
            let host = NSHostingView(rootView: EditorView(store: store, windows: self, loginItem: loginItem))
            host.sizingOptions = []
            window.contentView = host
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.setFrameAutosaveName("Daylight.Editor.v2")
            if !window.setFrameUsingName("Daylight.Editor.v2") { window.center() }
            editorWindow = window
        }
        // Even an unminimized window can receive a delayed Dock restore response,
        // which would raise the editor over tiles after a later status-item click.
        if editorWindow?.isMiniaturized == true { editorWindow?.deminiaturize(nil) }
        NSApp.activate(ignoringOtherApps: true)
        editorWindow?.makeKeyAndOrderFront(nil)
    }

    func edit(_ id: UUID) { store.selectedID = id; showEditor() }
    @objc func newCountdown() { store.add(); showEditor() }
    @objc func newTimer() { showEditor(); timerSetupOpen = true }
    func startTimer(_ timer: FocusTimer, title: String, palette: PalettePreset = .ember) {
        guard let id = store.addTimer(timer, title: title) else { return }
        store.update(id) { palette.apply(to: &$0.countdown) }
        store.saveNow()
        showWidget(id)
    }
    func acknowledgeTimer(_ id: UUID) {
        store.acknowledgeTimer(id)
        refreshTimers()
    }

    private func refreshTimers() {
        guard !terminating, !store.readFailed else { return }
        if store.entries.contains(where: { $0.timer != nil }) {
            if timerActivity == nil {
                timerActivity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep, reason: "Running a focus timer")
            }
        } else if let activity = timerActivity {
            ProcessInfo.processInfo.endActivity(activity)
            timerActivity = nil
        }
        let finished = store.entries.filter { $0.timer?.snapshot().isFinished == true }
        let ids = Set(finished.map(\.id))
        announcedTimers.formIntersection(ids)
        for entry in finished where !announcedTimers.contains(entry.id) {
            announcedTimers.insert(entry.id)
            showWidget(entry.id)
            applyWindowOptions(entry)
        }
        if finished.isEmpty {
            alarmSound?.stop()
            if alarmPlaying { alarmPlaying = false }
        } else {
            if alarmSound == nil {
                alarmSound = Bundle.main.url(forResource: "TimerChime", withExtension: "wav")
                    .flatMap { NSSound(contentsOf: $0, byReference: false) } ?? NSSound(named: NSSound.Name("Glass"))
                alarmSound?.loops = true
                alarmSound?.volume = 0.65
            }
            if let alarmSound, !alarmSound.isPlaying { alarmSound.play() }
            let playing = alarmSound?.isPlaying == true
            if alarmPlaying != playing { alarmPlaying = playing }
        }
    }
    @objc func showSelectedWidget() { if let id = store.selectedID { showWidget(id) } }
    func showWidget(_ id: UUID) {
        guard let entry = store.entry(id) else { return }
        tilePresentation = .normal
        store.setVisible(id, true)
        let window = ensureWidget(entry)
        applyWindowOptions(entry)
        if editorWindow?.isVisible == true {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        } else {
            window.orderFrontRegardless()
        }
    }
    @objc func showAllWidgets() { store.setAllVisible(true); syncWindows(store.library) }
    @objc func bringAllWidgetsToFront() {
        tilePresentation = .raised
        showAllWidgets()
        for entry in store.entries {
            guard let window = widgetWindows[entry.id] else { continue }
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.orderFrontRegardless()
        }
    }
    private func sendAllWidgetsToBack() {
        tilePresentation = .lowered
        for entry in store.entries {
            guard let window = widgetWindows[entry.id], !fullScreenIDs.contains(entry.id),
                  !window.styleMask.contains(.fullScreen) else { continue }
            // Temporarily lower pinned tiles too, while retaining the saved preference.
            applyWindowOptions(entry)
            window.orderBack(nil)
        }
    }
    @objc func hideAllWidgets() {
        tilePresentation = .normal
        store.setAllVisible(false); syncWindows(store.library)
    }
    @objc func autoArrange() {
        guard fullScreenIDs.isEmpty else {
            arrangementMessage = "Exit full screen before arranging tiles."
            return
        }
        showAllWidgets()
        let screens = NSScreen.screens
        let entries = TileArrangement.nearestFirst(store.entries)
        let items = entries.map { entry in
            let current = widgetWindows[entry.id]?.screen
            let index = screens.firstIndex { $0 === current } ?? screens.firstIndex {
                stableDisplayID($0) == displayLayouts.placement(for: entry)?.displayID
            } ?? 0
            return TileArrangement.Item(id: entry.id, size: dimensions(entry.countdown.size), screenIndex: index)
        }
        let result = TileArrangement.arrangeOnCurrentScreens(items, screens: screens.map(\.visibleFrame))
        restoringFrame = true
        for placement in result.placements {
            widgetWindows[placement.id]?.setFrame(placement.frame, display: true)
        }
        restoringFrame = false
        for placement in result.placements {
            if let window = widgetWindows[placement.id] { savePlacement(placement.id, window, userInitiated: true) }
        }
        store.saveNow()
        arrangementMessage = result.unplaced.isEmpty ? nil : "Not enough space on their current displays for \(result.unplaced.count) more tiles at X-small. Those tiles kept their previous positions."
        editorWindow?.orderFront(nil)
    }

    func hideWidget(_ id: UUID) { widgetWindows[id]?.close() }

    private func syncWindows(_ library: CountdownLibrary) {
        guard !terminating, !store.readFailed else { return }
        let visible = Set(library.entries.filter(\.isVisible).map(\.id))
        for id in Array(widgetWindows.keys) where !visible.contains(id) {
            if let window = widgetWindows[id] { savePlacement(id, window) }
            let window = widgetWindows.removeValue(forKey: id)
            fullScreenIDs.remove(id)
            window?.close()
        }
        for entry in library.entries where entry.isVisible {
            let isNew = widgetWindows[entry.id] == nil
            let window = ensureWidget(entry)
            applyWindowOptions(entry)
            if isNew { window.orderFront(nil) }
        }
        updateTileHoverTimer()
        if tilePresentation != .raised, editorWindow?.isKeyWindow == true { editorWindow?.orderFront(nil) }
    }

    private func ensureWidget(_ entry: CountdownEntry) -> NSWindow {
        if let existing = widgetWindows[entry.id] { return existing }
        let size = dimensions(entry.countdown.size)
        let window = TileWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.openEditor = { [weak self] in self?.edit(entry.id) }
        window.beginUserMove = { [weak self] in self?.userPlacementEdits.insert(entry.id) }
        window.selectOccasion = { [weak self] in
            guard let self, self.editorWindow?.isVisible == true else { return }
            self.edit(entry.id)
        }
        window.title = entry.countdown.displayTitle + " — Daylight"
        window.setCloseControlHovered(false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.acceptsMouseMovedEvents = true
        window.hidesOnDeactivate = false
        window.backgroundColor = NSColor(entry.countdown.theme.background)
        window.minSize = dimensions(.extraSmall)
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        let host = TileHostingView(rootView: DesktopView(store: store, windows: self, countdownID: entry.id).ignoresSafeArea())
        host.sizingOptions = []
        window.contentView = host
        window.isReleasedWhenClosed = false
        widgetWindows[entry.id] = window
        restoringFrame = true
        if let placement = displayLayouts.placement(for: entry, index: store.entries.firstIndex { $0.id == entry.id } ?? 0) {
            restorePlacement(placement, to: window)
        } else if store.entries.count == 1 && window.setFrameUsingName("Daylight.Desktop") {
            recoverOffscreenWindow(window)
        } else {
            window.center()
            if let screen = window.screen {
                let offset = Double((widgetWindows.count - 1) % 6) * 28
                let placement = WidgetPlacement(x: window.frame.minX - screen.visibleFrame.minX + offset,
                                                y: window.frame.minY - screen.visibleFrame.minY - offset,
                                                width: size.width, height: size.height, displayID: stableDisplayID(screen))
                window.setFrame(placement.frame(in: screen.visibleFrame), display: false)
            }
        }
        restoringFrame = false
        window.delegate = self
        applyWindowOptions(entry)
        // A separate turn avoids modifying SwiftUI state while constructing a view.
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window, self.widgetWindows[entry.id] === window else { return }
            self.store.updateLibrary { self.displayLayouts.ensurePlacements(in: &$0) }
        }
        return window
    }

    func resizeWidget(_ size: WidgetSize) { if let id = store.selectedID { resizeWidget(size, id: id) } }
    func resizeWidget(_ size: WidgetSize, id: UUID) {
        guard !fullScreenIDs.contains(id) else { return }
        let target = dimensions(size)
        guard let window = widgetWindows[id] else {
            guard let entry = store.entry(id), var placement = displayLayouts.placement(for: entry) else { return }
            placement.x += (placement.width - target.width) / 2
            placement.y += (placement.height - target.height) / 2
            placement.width = target.width
            placement.height = target.height
            displayLayouts.recordEdit(placement, for: id, currentDisplays: currentWidgetDisplays())
            store.updateLibrary { displayLayouts.flushEdits(in: &$0) }
            return
        }
        guard let screen = window.screen ?? NSScreen.main else { return }
        let placement = WidgetPlacement(x: window.frame.midX - target.width / 2 - screen.visibleFrame.minX,
                                        y: window.frame.midY - target.height / 2 - screen.visibleFrame.minY,
                                        width: target.width, height: target.height, displayID: stableDisplayID(screen))
        userPlacementEdits.insert(id)
        window.setFrame(placement.frame(in: screen.visibleFrame), display: true, animate: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }

    func moveWidget(_ id: UUID, to displayID: CGDirectDisplayID) {
        guard !fullScreenIDs.contains(id), let screen = NSScreen.screens.first(where: { screenID($0) == displayID }) else { return }
        showWidget(id)
        guard let window = widgetWindows[id] else { return }
        let visible = screen.visibleFrame
        let placement = WidgetPlacement(x: (visible.width - window.frame.width) / 2, y: (visible.height - window.frame.height) / 2,
                                        width: window.frame.width, height: window.frame.height, displayID: stableDisplayID(screen))
        userPlacementEdits.insert(id)
        window.setFrame(placement.frame(in: visible), display: true)
        savePlacement(id, window, userInitiated: true)
    }

    @objc func toggleSelectedFullScreen() { if let id = activeCountdownID { toggleFullScreen(id) } }
    func toggleFullScreen(_ id: UUID) {
        showWidget(id)
        guard let window = widgetWindows[id] else { return }
        if !window.styleMask.contains(.fullScreen) {
            savePlacement(id, window)
            window.level = .normal
            window.collectionBehavior = [.fullScreenPrimary]
        }
        window.toggleFullScreen(nil)
    }
    func exitFullScreen(_ id: UUID) {
        guard let window = widgetWindows[id], window.styleMask.contains(.fullScreen) else { return }
        window.toggleFullScreen(nil)
    }

    private func id(for window: NSWindow) -> UUID? { widgetWindows.first { $0.value === window }?.key }
    private var activeCountdownID: UUID? {
        if let window = NSApp.keyWindow, let id = id(for: window) { return id }
        return store.selectedID
    }
    func windowWillEnterFullScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, let id = id(for: window) else { return }
        savePlacement(id, window)
        fullScreenIDs.insert(id)
        window.level = .normal
    }
    func windowDidExitFullScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, let id = id(for: window) else { return }
        fullScreenIDs.remove(id)
        if let entry = store.entry(id) {
            if let placement = displayLayouts.placement(for: entry) {
                restoringFrame = true
                restorePlacement(placement, to: window)
                restoringFrame = false
            }
            applyWindowOptions(entry)
        }
    }
    func windowDidFailToEnterFullScreen(_ window: NSWindow) {
        guard let id = id(for: window) else { return }
        fullScreenIDs.remove(id)
        if let entry = store.entry(id) { applyWindowOptions(entry) }
    }
    func windowWillClose(_ notification: Notification) {
        guard !terminating, let window = notification.object as? NSWindow else { return }
        if window === editorWindow {
            timerSetupOpen = false
            if NSApp.activationPolicy() != .accessory { NSApp.setActivationPolicy(.accessory) }
            NSApp.deactivate()
            return
        }
        guard let id = id(for: window) else { return }
        savePlacement(id, window)
        widgetWindows.removeValue(forKey: id)
        fullScreenIDs.remove(id)
        store.setVisible(id, false)
        store.saveNow()
    }
    func windowDidMove(_ notification: Notification) { recordPlacement(notification) }
    func windowDidResize(_ notification: Notification) { recordPlacement(notification) }
    private func recordPlacement(_ notification: Notification) {
        guard !restoringFrame, !displayConfigurationChanging,
              let window = notification.object as? NSWindow, let id = id(for: window),
              !fullScreenIDs.contains(id), !window.styleMask.contains(.fullScreen) else { return }
        guard userPlacementEdits.contains(id) else {
            // A dock can issue a final Window Server move after screens have settled.
            // Reapply the layout instead of treating that move as a user's edit.
            if let entry = store.entry(id), let placement = displayLayouts.placement(for: entry),
               let expected = placement.restoredFrame(on: currentWidgetDisplays()), window.frame != expected {
                refreshDisplays()
            }
            return
        }
        capturePlacementEdit(id, window)
        placementSaveTasks[id]?.cancel()
        placementSaveTasks[id] = Task { @MainActor [weak self, weak window] in
            do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
            guard !Task.isCancelled, let self else { return }
            self.placementSaveTasks.removeValue(forKey: id)
            guard let window, self.widgetWindows[id] === window else { return }
            self.savePlacement(id, window)
        }
    }
    func windowWillStartLiveResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, let id = id(for: window) else { return }
        userPlacementEdits.insert(id)
    }
    func windowDidEndLiveResize(_ notification: Notification) {
        guard !restoringFrame, let window = notification.object as? NSWindow, let id = id(for: window) else { return }
        if userPlacementEdits.contains(id) { capturePlacementEdit(id, window) }
        savePlacement(id, window)
    }
    private func savePlacement(_ id: UUID, _ window: NSWindow, userInitiated: Bool = false) {
        placementSaveTasks.removeValue(forKey: id)?.cancel()
        if userInitiated { capturePlacementEdit(id, window) }
        // A drag can pause longer than the save debounce before crossing displays.
        if NSEvent.pressedMouseButtons & 1 == 0 { userPlacementEdits.remove(id) }
        store.updateLibrary { displayLayouts.flushEdits(in: &$0) }
    }
    private func capturePlacementEdit(_ id: UUID, _ window: NSWindow) {
        guard !restoringFrame, !displayConfigurationChanging,
              !fullScreenIDs.contains(id), !window.styleMask.contains(.fullScreen) else { return }
        let screens = currentWidgetDisplays()
        // Use geometry rather than NSWindow.screen, which can lag behind a cross-display drag.
        guard let screen = screens.max(by: {
            let a = $0.visibleFrame.intersection(window.frame), b = $1.visibleFrame.intersection(window.frame)
            return a.width * a.height < b.width * b.height
        }), screen.visibleFrame.intersects(window.frame) else { return }
        displayLayouts.recordEdit(WidgetPlacement(frame: window.frame, on: screen), for: id, currentDisplays: screens)
    }

    private func applyWindowOptions(_ entry: CountdownEntry) {
        guard let window = widgetWindows[entry.id] else { return }
        let title = entry.countdown.displayTitle + " — Daylight"
        if window.title != title { window.title = title }
        let background = NSColor(entry.countdown.theme.background)
        if window.backgroundColor != background { window.backgroundColor = background }
        (window as? TileWindow)?.hasAcknowledgmentButton = entry.timer?.snapshot().isFinished == true
        guard !fullScreenIDs.contains(entry.id), !window.styleMask.contains(.fullScreen) else { return }
        let finishedTimer = entry.timer?.snapshot().isFinished == true
        let level: NSWindow.Level = tilePresentation != .lowered && (entry.countdown.alwaysOnTop || finishedTimer) ? .floating : .normal
        if window.level != level { window.level = level }
        let behavior: NSWindow.CollectionBehavior = entry.countdown.allSpaces || finishedTimer ? [.canJoinAllSpaces, .fullScreenPrimary] : [.fullScreenPrimary]
        if window.collectionBehavior != behavior { window.collectionBehavior = behavior }
    }
    private func dimensions(_ size: WidgetSize) -> NSSize {
        NSSize(width: size.width, height: size.height)
    }
    private func screenID(_ screen: NSScreen) -> CGDirectDisplayID {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
    private func stableDisplayID(_ screen: NSScreen) -> String {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(screenID(screen))?.takeRetainedValue() else { return screen.localizedName }
        return CFUUIDCreateString(nil, uuid) as String
    }
    private func recoverOffscreenWindow(_ window: NSWindow) {
        if !NSScreen.screens.contains(where: { $0.visibleFrame.insetBy(dx: 60, dy: 60).intersects(window.frame) }) { window.center() }
    }
    private func restorePlacement(_ placement: WidgetPlacement, to window: NSWindow) {
        if let frame = placement.restoredFrame(on: currentWidgetDisplays()) {
            window.setFrame(frame, display: true)
        }
    }
    private func currentWidgetDisplays() -> [WidgetDisplay] {
        displaySource?() ?? NSScreen.screens.map { WidgetDisplay(id: stableDisplayID($0), visibleFrame: $0.visibleFrame) }
    }
    func beginDisplayReconfiguration() {
        guard !terminating else { return }
        store.updateLibrary { displayLayouts.beginReconfiguration(in: &$0) }
        displayConfigurationChanging = true
        displayRefreshTask?.cancel()
        for task in placementSaveTasks.values { task.cancel() }
        placementSaveTasks.removeAll()
        userPlacementEdits.removeAll()
    }
    @objc func refreshDisplays() {
        guard !terminating else { return }
        beginDisplayReconfiguration()
        displays = NSScreen.screens.map { DisplayChoice(id: screenID($0), name: $0.localizedName) }
        // Docks can expose their displays in stages. Require a quiet interval with
        // unchanged identities and geometry; intermediate setups never overwrite others.
        displayRefreshTask = Task { @MainActor [weak self] in
            var previous = self?.currentWidgetDisplays() ?? []
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                guard let self, !self.terminating else { return }
                let current = self.currentWidgetDisplays()
                guard !current.isEmpty, current == previous else {
                    previous = current
                    continue
                }
                self.displays = NSScreen.screens.map { DisplayChoice(id: self.screenID($0), name: $0.localizedName) }
                self.store.updateLibrary { _ = self.displayLayouts.activate(current, in: &$0) }
                self.restoringFrame = true
                for (id, window) in self.widgetWindows where !self.fullScreenIDs.contains(id) && !window.styleMask.contains(.fullScreen) {
                    if let entry = self.store.entry(id), let placement = self.displayLayouts.placement(for: entry) {
                        self.restorePlacement(placement, to: window)
                    }
                }
                self.restoringFrame = false
                self.displayConfigurationChanging = false
                self.displayRefreshTask = nil
                self.store.saveNow()
                return
            }
        }
    }
    @objc private func refreshAfterWake(_ notification: Notification) {
        if notification.name == NSWorkspace.didWakeNotification { refreshDisplays() }
        store.objectWillChange.send(); refreshTimers(); updateStatus(store.library)
    }
    @objc private func editTitle() {
        if let id = activeCountdownID { store.selectedID = id }
        showEditor()
        NotificationCenter.default.post(name: .editCountdownTitle, object: nil)
    }
    @objc private func togglePin() { if let id = activeCountdownID { store.update(id) { $0.countdown.alwaysOnTop.toggle() } } }
    @objc private func chooseNumber() { changeActiveStyle(.number) }
    @objc private func chooseRing() { changeActiveStyle(.ring) }
    @objc private func chooseFlip() { changeActiveStyle(.flip) }
    @objc private func chooseGrid() { changeActiveStyle(.grid) }
    private func changeActiveStyle(_ style: CountdownStyle) {
        if let id = activeCountdownID, store.entry(id)?.timer == nil { store.update(id) { $0.countdown.style = style } }
    }

    private func menuItem(_ title: String, _ action: Selector, key: String = "", modifiers: NSEvent.ModifierFlags = [.command]) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self; item.keyEquivalentModifierMask = modifiers
        return item
    }
    private func buildMenu() {
        let main = NSMenu()
        let app = NSMenu()
        let appItem = NSMenuItem(); appItem.submenu = app; main.addItem(appItem)
        app.addItem(menuItem("About Daylight", #selector(showAbout)))
        app.addItem(.separator())
        app.addItem(NSMenuItem(title: "Quit Daylight", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        let edit = NSMenu(title: "Edit")
        let editItem = NSMenuItem(); editItem.submenu = edit; main.addItem(editItem)
        for (title, action, key) in [("Undo", "undo:", "z"), ("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            edit.addItem(NSMenuItem(title: title, action: Selector(action), keyEquivalent: key))
        }
        let view = NSMenu(title: "View")
        let viewItem = NSMenuItem(); viewItem.submenu = view; main.addItem(viewItem)
        view.addItem(menuItem("New countdown", #selector(newCountdown), key: "n"))
        view.addItem(menuItem("New timer…", #selector(newTimer), key: "t"))
        view.addItem(menuItem("Edit countdown", #selector(editTitle), key: "e"))
        view.addItem(menuItem("Open desktop widget", #selector(showSelectedWidget), key: "d"))
        view.addItem(menuItem("Auto arrange tiles", #selector(autoArrange)))
        view.addItem(menuItem("Toggle full screen", #selector(toggleSelectedFullScreen), key: "f", modifiers: [.command, .control]))
        view.addItem(menuItem("Keep widget on top", #selector(togglePin), key: "p", modifiers: [.command, .shift]))
        view.addItem(.separator())
        view.addItem(menuItem("Number", #selector(chooseNumber), key: "1"))
        view.addItem(menuItem("Ring", #selector(chooseRing), key: "2"))
        view.addItem(menuItem("Flip clock", #selector(chooseFlip), key: "3"))
        view.addItem(menuItem("Day grid", #selector(chooseGrid), key: "4"))
        let window = NSMenu(title: "Window")
        let windowItem = NSMenuItem(); windowItem.submenu = window; main.addItem(windowItem)
        window.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        NSApp.windowsMenu = window; NSApp.mainMenu = main
    }
    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu(); menu.delegate = self; statusMenu = menu
        // An attached statusItem.menu consumes clicks before the button action can run.
        if let button = statusItem?.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.ignoresMultiClick = false
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityLabel("Daylight")
            button.setAccessibilityHelp(statusClickHelp)
        }
        updateStatus(store.library)
    }
    private var statusClickHelp: String {
        "Click for the menu. Right-click or Control-click to bring tiles forward or send them back."
    }
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        handleStatusItemClick(NSApp.currentEvent) {
            statusMenu?.popUp(positioning: nil, at: NSPoint(x: sender.bounds.minX, y: sender.bounds.minY), in: sender)
        }
    }
    func handleStatusItemClick(_ event: NSEvent?, showMenu: () -> Void) {
        let secondaryClick = event?.type == .rightMouseUp ||
            (event?.type == .leftMouseUp && event?.modifierFlags.contains(.control) == true)
        guard secondaryClick else {
            showMenu()
            return
        }
        if tilePresentation == .raised && store.entries.allSatisfy(\.isVisible) && tilesAreUncovered() {
            sendAllWidgetsToBack()
        } else {
            bringAllWidgetsToFront()
        }
    }
    private func tilesAreUncovered() -> Bool {
        let ids = Set(widgetWindows.values.map(\.windowNumber))
        guard !ids.isEmpty else { return false }
        // Read geometry and stacking only, once per click; no window titles or screen capture.
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return true // Keep the explicit toggle usable if Window Server metadata is unavailable.
        }
        let windows: [TileWindowVisibility.Window] = info.compactMap { value in
            guard let id = value[kCGWindowNumber as String] as? Int,
                  let level = value[kCGWindowLayer as String] as? Int,
                  level >= NSWindow.Level.normal.rawValue, level < NSWindow.Level.mainMenu.rawValue,
                  (value[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  let bounds = value[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return nil }
            return TileWindowVisibility.Window(id: id, frame: frame, level: level)
        }
        return TileWindowVisibility.areUncovered(ids, in: windows)
    }
    func menuWillOpen(_ menu: NSMenu) {
        guard menu === statusMenu else { return }
        menu.removeAllItems()
        menu.addItem(menuItem("Manage countdowns…", #selector(showEditor)))
        menu.addItem(menuItem("New countdown…", #selector(newCountdown)))
        menu.addItem(menuItem("New timer…", #selector(newTimer)))
        menu.addItem(.separator())
        for entry in store.entries {
            let state = entry.countdown.snapshot()
            let timerState = entry.timer?.snapshot()
            let remaining = timerState.map { $0.isFinished ? "Time’s up" : $0.clock } ?? (state.hasPassed ? "Arrived" : "\(state.days)d")
            let item = menuItem(entry.countdown.displayTitle + " · " + remaining, #selector(openEntry(_:)))
            item.representedObject = entry.id.uuidString
            item.state = entry.isVisible ? .on : .off
            menu.addItem(item)
            if timerState?.isFinished == true {
                let acknowledge = menuItem("Acknowledge \(entry.countdown.displayTitle)", #selector(acknowledgeEntry(_:)))
                acknowledge.representedObject = entry.id.uuidString
                menu.addItem(acknowledge)
            }
        }
        menu.addItem(.separator())
        menu.addItem(menuItem("Auto arrange tiles", #selector(autoArrange)))
        menu.addItem(menuItem("Show all widgets", #selector(bringAllWidgetsToFront)))
        menu.addItem(menuItem("Hide all widgets", #selector(hideAllWidgets)))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Daylight", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }
    @objc private func openEntry(_ item: NSMenuItem) {
        guard let text = item.representedObject as? String, let id = UUID(uuidString: text) else { return }
        showWidget(id)
    }
    @objc private func acknowledgeEntry(_ item: NSMenuItem) {
        guard let value = item.representedObject as? String, let id = UUID(uuidString: value) else { return }
        acknowledgeTimer(id)
    }
    private func updateStatus(_ library: CountdownLibrary) {
        if let nextTimer = library.entries.filter({ $0.timer != nil }).min(by: { $0.timer!.endsAt < $1.timer!.endsAt }), let focus = nextTimer.timer {
            let state = focus.snapshot()
            statusItem?.button?.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Focus timers")
            statusItem?.button?.title = state.isFinished ? " Done" : " \(state.clock)"
            statusItem?.button?.toolTip = "\(nextTimer.countdown.displayTitle)\n\(statusClickHelp)"
            return
        }
        let next = library.entries.filter { $0.timer == nil && !$0.countdown.snapshot().hasPassed }.min { $0.countdown.target.date() < $1.countdown.target.date() }
        statusItem?.button?.image = NSImage(systemSymbolName: "circle.dotted.circle", accessibilityDescription: "Daylight countdowns")
        statusItem?.button?.imagePosition = .imageLeading
        if let next {
            let state = next.countdown.snapshot()
            statusItem?.button?.title = state.isToday ? " Today" : " \(state.days)d"
            statusItem?.button?.toolTip = "Daylight · \(library.entries.count) countdowns · \(next.countdown.displayTitle)\n\(statusClickHelp)"
        } else {
            statusItem?.button?.title = ""
            statusItem?.button?.toolTip = "Daylight\n\(statusClickHelp)"
        }
    }
    @objc private func showAbout() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.6.10"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "21"
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "Daylight", .applicationVersion: "\(version) (\(build))",
                                                    .credits: NSAttributedString(string: "A day worth waiting for.\nIndependent countdowns, quietly on your desktop.")])
    }
}

@main
enum DaylightApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppController()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
