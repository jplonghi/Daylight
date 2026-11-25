import SwiftUI
import DaylightCore

struct TimerSetupView: View {
    @ObservedObject var windows: AppController
    @Environment(\.dismiss) private var dismiss
    @State private var title = "Focus timer"
    @State private var minutesText = "45"
    @State private var finishHour: String
    @State private var finishMinute: String
    @State private var finishIsPM: Bool
    @FocusState private var focusedTimePart: TimePart?
    @State private var mode = Mode.duration
    @State private var palette = PalettePreset.ember

    private enum Mode: String, CaseIterable { case duration = "Duration", clock = "Finish at" }
    private typealias TimePart = FinishTimePart

    init(windows: AppController) {
        self.windows = windows
        let initial = Date().addingTimeInterval(45 * 60)
        let calendar = Calendar.autoupdatingCurrent
        let hour = calendar.component(.hour, from: initial)
        _finishHour = State(initialValue: String((hour + 11) % 12 + 1))
        _finishMinute = State(initialValue: String(format: "%02d", calendar.component(.minute, from: initial)))
        _finishIsPM = State(initialValue: hour >= 12)
    }

    private var minutes: Int? { Int(minutesText.trimmingCharacters(in: .whitespacesAndNewlines)) }
    private var validClockInput: Bool {
        guard let hour = Int(finishHour), let minute = Int(finishMinute) else { return false }
        return (1...12).contains(hour) && (0...59).contains(minute)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let timer = proposedTimer(now: context.date)
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 12) {
                    Image(systemName: "timer").font(.system(size: 27, weight: .light)).foregroundStyle(Design.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("New focus timer").font(.system(size: 23, weight: .semibold, design: .rounded))
                        Text("A little time, just for this.").font(.system(size: 12)).foregroundStyle(Design.muted)
                    }
                }
                TextField("What are you focusing on?", text: $title)
                    .textFieldStyle(.roundedBorder).controlSize(.large)
                    .accessibilityLabel("Timer title")
                Picker("Timer mode", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden()
                if mode == .duration {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            ForEach([15, 25, 45, 60], id: \.self) { preset in
                                Button { minutesText = String(preset) } label: {
                                    Text("\(preset) min").font(.system(size: 12, weight: .medium))
                                        .frame(maxWidth: .infinity).frame(height: 36).contentShape(Rectangle())
                                        .background(minutes == preset ? Color.white : Design.line.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
                                        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(minutes == preset ? Design.orange : Design.line).allowsHitTesting(false) }
                                }
                                .buttonStyle(.plain).accessibilityAddTraits(minutes == preset ? .isSelected : [])
                            }
                        }
                        HStack {
                            Text("Custom duration").font(.system(size: 12))
                            Spacer()
                            TextField("Minutes", text: $minutesText)
                                .frame(width: 65).textFieldStyle(.roundedBorder).accessibilityLabel("Custom minutes")
                            Text("minutes").font(.system(size: 12)).foregroundStyle(Design.muted)
                        }
                    }
                } else {
                    finishTimeControls
                }
                Text(timer.map { Calendar.autoupdatingCurrent.isDateInToday($0.endsAt)
                        ? "Finishes today at \($0.endsAt.formatted(date: .omitted, time: .shortened))"
                        : "Finishes \($0.endsAt.formatted(date: .abbreviated, time: .shortened))" }
                     ?? (mode == .clock
                         ? (validClockInput ? "Choose a time later today." : "Enter an hour from 1–12 and minutes from 00–59.")
                         : "Enter a duration from 1 to 1,440 minutes."))
                    .font(.system(size: 12)).foregroundStyle(timer == nil ? Design.orange : Design.muted)
                VStack(alignment: .leading, spacing: 9) {
                    Text("Colors").font(.system(size: 12, weight: .medium))
                    PalettePresetsView(theme: palette.theme, accent: palette.accent, columns: 3) { palette = $0 }
                }
                Divider()
                Text("A gentle chime repeats when time is up. Acknowledge it to dismiss the timer.")
                    .font(.system(size: 12)).foregroundStyle(Design.muted).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Start timer") {
                        guard let value = proposedTimer(now: Date()) else { return }
                        windows.startTimer(value, title: title, palette: palette)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent).tint(Design.orange)
                    .keyboardShortcut(.defaultAction).disabled(timer == nil)
                }
            }
            .padding(28).frame(width: 440)
            .background(Design.canvas).foregroundStyle(Design.ink).preferredColorScheme(.light)
        }
    }

    private var finishTimeControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today at").font(.system(size: 13, weight: .medium))
            HStack(alignment: .top, spacing: 8) {
                timeField("Hour", text: $finishHour, part: .hour)
                Text(":").font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundStyle(Design.muted).frame(height: 56)
                    .padding(.top, 19)
                    .accessibilityHidden(true)
                timeField("Minute", text: $finishMinute, part: .minute)
                Spacer(minLength: 8)
                VStack(alignment: .leading, spacing: 6) {
                    Text("AM / PM").font(.system(size: 11, weight: .medium)).foregroundStyle(Design.muted)
                    HStack(spacing: 6) {
                        periodButton("AM", isPM: false)
                        periodButton("PM", isPM: true)
                    }
                }
            }
        }
        .onChange(of: focusedTimePart) { previous, current in
            if previous == .minute, let minute = Int(finishMinute), (0...59).contains(minute) {
                finishMinute = String(format: "%02d", minute)
            }
            if current != nil {
                // Select the whole value once the native field editor receives focus.
                DispatchQueue.main.async {
                    guard focusedTimePart == current else { return }
                    NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                }
            }
        }
    }

    private func timeField(_ label: String, text: Binding<String>, part: TimePart) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(Design.muted)
            TextField(part == .hour ? "12" : "00", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 30, weight: .medium, design: .rounded).monospacedDigit())
                .multilineTextAlignment(.center)
                .focused($focusedTimePart, equals: part)
                .frame(width: 84, height: 56)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(focusedTimePart == part ? Design.orange : Design.line, lineWidth: focusedTimePart == part ? 2 : 1)
                        .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                .onTapGesture { focusedTimePart = part }
                .background {
                    TimeFieldScrollArea { steps in adjustTime(part, by: steps) }
                }
                .accessibilityLabel("Finish \(label.lowercased())")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: adjustTime(part, by: 1)
                    case .decrement: adjustTime(part, by: -1)
                    @unknown default: break
                    }
                }
                .help("Type or scroll to change the \(label.lowercased()).")
            HStack(spacing: 4) {
                timeArrow(label, part: part, increment: 1)
                timeArrow(label, part: part, increment: -1)
            }
        }
    }

    private func timeArrow(_ label: String, part: TimePart, increment: Int) -> some View {
        Button { adjustTime(part, by: increment) } label: {
            Image(systemName: increment > 0 ? "chevron.up" : "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 40, height: 30)
                .contentShape(Rectangle())
                .background(Color.white, in: RoundedRectangle(cornerRadius: 7))
                .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(Design.line).allowsHitTesting(false) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(increment > 0 ? "Increase" : "Decrease") finish \(label.lowercased())")
        .help("\(increment > 0 ? "Increase" : "Decrease") \(label.lowercased())")
    }

    private func adjustTime(_ part: TimePart, by steps: Int) {
        switch part {
        case .hour: finishHour = part.adjusting(finishHour, by: steps)
        case .minute: finishMinute = part.adjusting(finishMinute, by: steps)
        }
    }

    private func periodButton(_ label: String, isPM: Bool) -> some View {
        Button {
            focusedTimePart = nil
            finishIsPM = isPM
        } label: {
            Text(label).font(.system(size: 16, weight: .semibold, design: .rounded))
                .frame(width: 62, height: 56)
                .contentShape(Rectangle())
                .background(finishIsPM == isPM ? Design.orange : Color.white, in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(finishIsPM == isPM ? Color.white : Design.ink)
                .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(finishIsPM == isPM ? Design.orange : Design.line).allowsHitTesting(false) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(finishIsPM == isPM ? .isSelected : [])
    }

    private func proposedTimer(now: Date) -> FocusTimer? {
        if mode == .clock {
            guard let hour = Int(finishHour), let minute = Int(finishMinute) else { return nil }
            return FocusTimer.finishingToday(hour: hour, minute: minute, isPM: finishIsPM, now: now)
        }
        guard let minutes, (1...1440).contains(minutes) else { return nil }
        return FocusTimer(minutes: minutes, now: now)
    }
}
