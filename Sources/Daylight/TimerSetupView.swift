import SwiftUI
import DaylightCore

struct TimerSetupView: View {
    @ObservedObject var windows: AppController
    @Environment(\.dismiss) private var dismiss
    @State private var title = "Focus timer"
    @State private var minutesText = "45"
    @State private var finishAt = Date().addingTimeInterval(45 * 60)
    @State private var mode = Mode.duration
    @State private var palette = PalettePreset.ember

    private enum Mode: String, CaseIterable { case duration = "Duration", clock = "Finish at" }
    private var minutes: Int? { Int(minutesText.trimmingCharacters(in: .whitespacesAndNewlines)) }

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
                    HStack {
                        Text("Today at").font(.system(size: 13, weight: .medium))
                        Spacer()
                        DatePicker("Finish time today", selection: $finishAt, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.field).labelsHidden().controlSize(.large)
                    }
                    .frame(height: 88)
                }
                Text(timer.map { Calendar.autoupdatingCurrent.isDateInToday($0.endsAt)
                        ? "Finishes today at \($0.endsAt.formatted(date: .omitted, time: .shortened))"
                        : "Finishes \($0.endsAt.formatted(date: .abbreviated, time: .shortened))" }
                     ?? (mode == .clock ? "Choose a time later today." : "Enter a duration from 1 to 1,440 minutes."))
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

    private func proposedTimer(now: Date) -> FocusTimer? {
        if mode == .clock { return FocusTimer.finishingToday(at: finishAt, now: now) }
        guard let minutes, (1...1440).contains(minutes) else { return nil }
        return FocusTimer(minutes: minutes, now: now)
    }
}
