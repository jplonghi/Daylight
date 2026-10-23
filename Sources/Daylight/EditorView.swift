import SwiftUI
import DaylightCore

struct EditorView: View {
    @ObservedObject var store: CountdownStore
    @ObservedObject var windows: AppController
    @ObservedObject var loginItem: LoginItem
    @State private var calendarOpen = false
    @State private var timelineOpen = false
    @FocusState private var titleFocused: Bool
    private var selectedTimer: FocusTimer? { store.library.selected?.timer }

    private var targetDate: Binding<Date> {
        Binding(get: { store.countdown.target.date() }, set: { store.countdown.target = LocalDay($0) })
    }
    private var startDate: Binding<Date> {
        Binding(get: { store.countdown.started.date() }, set: { store.countdown.started = LocalDay($0) })
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Design.line).frame(height: 1)
            collectionBar
            Rectangle().fill(Design.line).frame(height: 1)
            if store.selectedID != nil {
                HStack(spacing: 0) {
                    sidebar.frame(width: 264)
                    Rectangle().fill(Design.line).frame(width: 1)
                    studio
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "sun.max").font(.system(size: 40, weight: .light)).foregroundStyle(Design.orange)
                    Text("A day worth waiting for").font(.system(size: 24, weight: .medium, design: .rounded))
                    Text("Add a countdown to make your first desktop widget.").foregroundStyle(Design.muted)
                    Button("New countdown", action: windows.newCountdown).buttonStyle(.borderedProminent).tint(Design.orange)
                    Button("New timer", action: windows.newTimer).buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if let message = windows.arrangementMessage {
                HStack {
                    Text(message).font(.system(size: 11))
                    Spacer()
                    Button("Dismiss") { windows.arrangementMessage = nil }
                }.padding(12).background(Design.line.opacity(0.5))
            }
            if let message = store.errorMessage {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(message).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("Retry", action: store.retry)
                    if store.readFailed { Button("Back up & start fresh", action: store.recoverWithBackup) }
                }
                .padding(12).background(Color(hex: 0xF5E5C5))
            }
        }
        .background(Design.canvas)
        .foregroundStyle(Design.ink)
        .preferredColorScheme(.light)
        .sheet(isPresented: $windows.timerSetupOpen) { TimerSetupView(windows: windows) }
        .onReceive(NotificationCenter.default.publisher(for: .editCountdownTitle)) { _ in titleFocused = true }
        .onChange(of: store.selectedID) { _, _ in calendarOpen = false; titleFocused = false }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().stroke(Design.orange.opacity(0.22), lineWidth: 2)
                Circle().trim(from: 0, to: 0.74).stroke(Design.orange, style: StrokeStyle(lineWidth: 2, lineCap: .round)).rotationEffect(.degrees(-90))
                Circle().fill(Design.orange).frame(width: 4, height: 4)
            }
            .frame(width: 24, height: 24)
            Text("daylight").font(.system(size: 22, weight: .semibold, design: .rounded)).tracking(-0.7)
            Spacer()
            creationButton("New countdown", symbol: "plus", action: windows.newCountdown)
                .keyboardShortcut("n", modifiers: .command)
            creationButton("New timer", symbol: "timer", action: windows.newTimer)
                .keyboardShortcut("t", modifiers: .command)
            Toggle("Launch at login", isOn: Binding(get: { loginItem.enabled || loginItem.needsApproval }, set: { loginItem.setEnabled($0) }))
                .toggleStyle(.switch).controlSize(.small).font(.system(size: 11)).fixedSize()
                .help("Restore your visible widgets when you log in, including after a restart")
            if loginItem.needsApproval || loginItem.message != nil {
                Button(loginItem.needsApproval ? "Finish setup…" : "Login settings…", action: loginItem.openSettings)
                    .font(.system(size: 11)).help(loginItem.message ?? "Allow Daylight in System Settings → Login Items")
            }

        }
        .padding(.horizontal, 25).frame(height: 65)
    }

    private var collectionBar: some View {
        HStack(spacing: 12) {
            if !store.entries.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(store.entries) { entry in
                                countdownTab(entry).id(entry.id)
                            }
                        }
                    }
                    .frame(height: 34)
                    .scrollIndicators(.automatic)
                    .onChange(of: store.selectedID) { _, id in
                        if let id { proxy.scrollTo(id, anchor: .center) }
                    }
                }
            }
            Spacer(minLength: 0)
            Button(action: windows.autoArrange) { Label("Auto arrange", systemImage: "rectangle.3.group") }
                .help("Arrange tiles on their current displays, nearest deadline first")
                .disabled(store.entries.isEmpty || !windows.fullScreenIDs.isEmpty)
            Button("Show all", action: windows.showAllWidgets)
                .accessibilityLabel("Show all widgets")
            Button("Hide all", action: windows.hideAllWidgets)
                .accessibilityLabel("Hide all widgets")
            IconButton(symbol: "trash", label: "Delete countdown", action: store.deleteSelected)
                .disabled(store.selectedID == nil)

        }
        .buttonStyle(.bordered).controlSize(.small)
        .padding(.horizontal, 24).padding(.vertical, 10)
    }

    private func countdownTab(_ entry: CountdownEntry) -> some View {
        let selected = entry.id == store.selectedID
        return Button { store.selectedID = entry.id } label: {
            HStack(spacing: 8) {
                Image(systemName: entry.timer == nil ? "calendar" : "timer").foregroundStyle(selected ? Design.orange : Design.muted)
                Text(entry.countdown.displayTitle)
                    .font(.system(size: 12, weight: selected ? .semibold : .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                if selected {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .semibold)).foregroundStyle(Design.orange)
                }
            }
            .padding(.horizontal, 12).frame(height: 34)
            .frame(minWidth: 110, maxWidth: 230)
            .contentShape(Rectangle())
            .background(selected ? Color.white : Color.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(selected ? Design.orange.opacity(0.65) : Design.line)
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit \(entry.countdown.displayTitle)")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .help(entry.countdown.displayTitle)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    VStack(alignment: .leading, spacing: 13) {
                        sectionLabel(selectedTimer == nil ? "YOUR COUNTDOWN" : "YOUR TIMER")
                        Text(selectedTimer == nil ? "What’s the occasion?" : "What are you focusing on?").font(.system(size: 12, weight: .medium))
                        TextField("My next big day", text: $store.countdown.title)
                            .font(.system(size: 14, weight: .medium))
                            .textFieldStyle(.plain)
                            .padding(11)
                            .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
                            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(titleFocused ? Design.orange : Design.line, lineWidth: 1) }
                            .focused($titleFocused)
                            .accessibilityLabel(selectedTimer == nil ? "Countdown title" : "Timer title")
                            .onChange(of: store.countdown.title) { _, value in
                                if value.count > 120 { store.countdown.title = String(value.prefix(120)) }
                            }
                    }
                    if let selectedTimer {
                        timerDetails(selectedTimer)
                    } else {
                    VStack(alignment: .leading, spacing: 11) {
                        Text("The big day").font(.system(size: 12, weight: .medium))
                        Button { calendarOpen.toggle() } label: {
                            HStack {
                                Image(systemName: "calendar").foregroundStyle(Design.orange)
                                Text(store.countdown.target.date().formatted(.dateTime.month(.abbreviated).day().year()))
                                    .font(.system(size: 13, weight: .medium))
                                Spacer()
                                Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(Design.muted)
                            }
                            .padding(12)
                            .contentShape(Rectangle())
                            .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
                            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(Design.line) }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Choose countdown date")
                        .popover(isPresented: $calendarOpen, arrowEdge: .trailing) {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Choose your day").font(.headline)
                                DatePicker("Target date", selection: targetDate, in: supportedDates, displayedComponents: .date)
                                    .datePickerStyle(.graphical).labelsHidden()
                                HStack {
                                    DatePicker("Date", selection: targetDate, in: supportedDates, displayedComponents: .date).labelsHidden()
                                    Spacer()
                                    Button("Done") { calendarOpen = false }.keyboardShortcut(.defaultAction)
                                }
                            }
                            .padding(20).frame(width: 300)
                        }
                        HStack(spacing: 7) {
                            ForEach([7, 30, 100], id: \.self) { days in
                                Button {
                                    store.countdown.target = LocalDay(Calendar.autoupdatingCurrent.date(byAdding: .day, value: days, to: Date())!)
                                    store.countdown.started = LocalDay(Date())
                                } label: {
                                    Text("+\(days) days").font(.system(size: 10, weight: .medium))
                                        .padding(.horizontal, 9).padding(.vertical, 6)
                                        .contentShape(Rectangle())
                                        .background(Design.ink.opacity(0.045), in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .help("Count down to \(days) days from today")
                            }
                        }
                    }
                    }
                    Divider().overlay(Design.line)
                    VStack(alignment: .leading, spacing: 14) {
                        sectionLabel("MAKE IT YOURS")
                        PalettePresetsView(theme: store.countdown.theme, accent: store.countdown.accent) { preset in
                            guard let id = store.selectedID else { return }
                            store.update(id) { preset.apply(to: &$0.countdown) }
                        }

                    }
                    Divider().overlay(Design.line)
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Keep widget on top", isOn: $store.countdown.alwaysOnTop)
                            .toggleStyle(.switch).controlSize(.mini).font(.system(size: 12))
                        Toggle("Show on all Spaces", isOn: $store.countdown.allSpaces)
                            .toggleStyle(.switch).controlSize(.mini).font(.system(size: 12))
                        if selectedTimer == nil {
                        DisclosureGroup("Progress timeline", isExpanded: $timelineOpen) {
                            VStack(alignment: .leading, spacing: 9) {
                                DatePicker("Counting from", selection: startDate, in: supportedDates.lowerBound...min(Date(), targetDate.wrappedValue), displayedComponents: .date)
                                    .font(.system(size: 11)).datePickerStyle(.field)
                                Text(store.countdown.style == .grid ? "Squares brighten as days pass from this day to your target date." : "The ring empties from this day to your target date.")
                                    .font(.system(size: 10)).foregroundStyle(Design.muted).fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.top, 10)
                        }
                        .font(.system(size: 11)).tint(Design.muted).padding(.top, 4)
                        }
                    }
                }
                .padding(23)
            }
            HStack(spacing: 6) {
                Circle().fill(store.errorMessage != nil ? Design.orange : Color(hex: 0x7E9480)).frame(width: 5, height: 5)
                Text(store.errorMessage != nil ? "Needs your attention" : (store.saved ? "Saved on this Mac" : "Saving…"))
                    .font(.system(size: 10)).foregroundStyle(Design.muted)
                Spacer()
                Image(systemName: "lock").font(.system(size: 10)).foregroundStyle(Design.muted)
            }
            .padding(.horizontal, 24).padding(.bottom, 21)
        }
    }

    private var studio: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack {
                sectionLabel("A LITTLE CLOSER, EVERY DAY")
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(Color(hex: 0x7D907A)).frame(width: 5, height: 5)
                    Text("Live preview").font(.system(size: 10)).foregroundStyle(Design.muted)
                }
            }
            sizedPreview
            if selectedTimer != nil {
                HStack {
                    Label("Ring timer", systemImage: "timer").font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text("One-time session").font(.system(size: 11)).foregroundStyle(Design.muted)
                }
                .frame(height: 62)
            } else {
            HStack(spacing: 10) {
                ForEach(CountdownStyle.allCases, id: \.self) { style in
                    styleButton(style)
                }
            }
            }
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DESKTOP SIZE").font(.system(size: 9, weight: .semibold)).tracking(1.3).foregroundStyle(Design.muted)
                    HStack(spacing: 0) {
                        ForEach(WidgetSize.allCases, id: \.self) { size in
                            Button { store.countdown.size = size; windows.resizeWidget(size) } label: {
                                Text(size.title).font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 9).padding(.vertical, 6)
                                    .contentShape(Rectangle())
                                    .background(store.countdown.size == size ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                                    .shadow(color: .black.opacity(store.countdown.size == size ? 0.05 : 0), radius: 2, y: 1)
                            }
                            .buttonStyle(.plain).accessibilityLabel("\(size.title) desktop size")
                            .accessibilityAddTraits(store.countdown.size == size ? .isSelected : [])
                            .disabled(windows.widgetFullScreen)
                            .help(windows.widgetFullScreen ? "Exit full screen to resize the widget" : "Resize the desktop widget")
                        }
                    }
                    .padding(3).background(Design.ink.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
                }
                Spacer(minLength: 10)

            }
            .padding(.top, 4)
        }
        .padding(28)
    }

    private func creationButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 12).frame(height: 34)
                .contentShape(Rectangle())
                .background(Color.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(Design.line).allowsHitTesting(false) }
        }
        .buttonStyle(.plain)
    }

    private var sizedPreview: some View {
        GeometryReader { geometry in
            let size = store.countdown.size
            let scale = min(1, min(geometry.size.width / size.width, max(1, geometry.size.height - 26) / size.height))
            VStack(spacing: 10) {
                Spacer(minLength: 0)
                TimelineView(.periodic(from: .now, by: selectedTimer == nil ? 60 : 1)) { context in
                    if let timer = selectedTimer, let id = store.selectedID {
                        FocusTimerFace(countdown: store.countdown, timer: timer, now: context.date) { windows.acknowledgeTimer(id) }
                    } else {
                        CountdownFace(countdown: store.countdown, now: context.date)
                    }
                }
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(Design.ink.opacity(0.06)) }
                .shadow(color: .black.opacity(0.09), radius: 18, x: 0, y: 9)
                .scaleEffect(scale)
                .frame(width: size.width * scale, height: size.height * scale)
                Text("\(Int(size.width)) × \(Int(size.height)) pt · \(scale < 0.995 ? "\(Int((scale * 100).rounded()))% preview" : "Actual size")")
                    .font(.system(size: 10)).foregroundStyle(Design.muted)
                Spacer(minLength: 0)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private func timerDetails(_ timer: FocusTimer) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let finished = timer.snapshot(at: context.date).isFinished
            VStack(alignment: .leading, spacing: 12) {
                Text(finished ? "Time’s up" : "Finishes at").font(.system(size: 12, weight: .medium))
                Text(timer.endsAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 13)).foregroundStyle(Design.muted)
                if finished {
                    Label(windows.alarmPlaying ? "Chime repeating" : "Timer finished", systemImage: "speaker.wave.2")
                        .font(.system(size: 11)).foregroundStyle(Design.orange)
                } else {
                    Button("Cancel timer", role: .destructive, action: store.deleteSelected)
                        .font(.system(size: 11)).buttonStyle(.borderless)
                }
            }
        }
    }

    private func styleButton(_ style: CountdownStyle) -> some View {
        let selected = store.countdown.style == style
        return Button { store.countdown.style = style } label: {
            HStack(spacing: 8) {
                Group {
                    switch style {
                    case .number: Text("12").font(.system(size: 25, weight: .light, design: .rounded))
                    case .ring: ZStack { Circle().trim(from: 0, to: 0.76).stroke(lineWidth: 2).rotationEffect(.degrees(-90)); Text("12").font(.system(size: 10, weight: .medium)) }.padding(1)
                    case .grid:
                        Image(systemName: "square.grid.3x3.fill").font(.system(size: 24, weight: .light))
                    case .flip: HStack(spacing: 2) { ForEach(["1", "2"], id: \.self) { digit in Text(digit).font(.system(size: 15, weight: .medium, design: .rounded)).frame(width: 14, height: 24).background(Design.ink.opacity(0.07), in: RoundedRectangle(cornerRadius: 3)).overlay { Rectangle().fill(Design.canvas).frame(height: 1) } } }
                    }
                }
                .frame(width: 32, height: 32)
                Text(style.title).font(.system(size: 11, weight: .medium))
                Spacer(minLength: 0)
                if selected { Image(systemName: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(Design.orange) }
            }
            .foregroundStyle(selected ? Design.ink : Design.muted)
            .padding(.horizontal, 10).frame(height: 62)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(selected ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: 11))
            .overlay { RoundedRectangle(cornerRadius: 11).strokeBorder(selected ? Design.orange.opacity(0.65) : Design.line, lineWidth: 1).allowsHitTesting(false) }
        }
        .buttonStyle(.plain).accessibilityLabel("\(style.title) style")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 9, weight: .semibold)).tracking(1.5).foregroundStyle(Design.muted)
    }

    private var supportedDates: ClosedRange<Date> {
        LocalDay(year: 1900, month: 1, day: 1).date()...LocalDay(year: 9999, month: 12, day: 31).date()
    }
}

extension Notification.Name {
    static let editCountdownTitle = Notification.Name("Daylight.editTitle")
}
