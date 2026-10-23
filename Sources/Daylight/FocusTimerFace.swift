import SwiftUI
import DaylightCore

struct FocusTimerFace: View {
    let countdown: Countdown
    let timer: FocusTimer
    let now: Date
    let acknowledge: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / 520, geometry.size.height / 440)
            let state = timer.snapshot(at: now)
            let diameter = 252 * scale
            ZStack {
                countdown.theme.background
                VStack(spacing: 0) {
                    Text(countdown.displayTitle)
                        .font(.system(size: max(12, 23 * scale), weight: .medium, design: .rounded))
                        .lineLimit(2).minimumScaleFactor(0.55).multilineTextAlignment(.center)
                        .frame(maxWidth: geometry.size.width * 0.85)
                    Spacer(minLength: 8 * scale)
                    ZStack {
                        Circle().stroke(countdown.theme.foreground.opacity(0.09), lineWidth: 9 * scale)
                        Circle().trim(from: 0, to: state.fraction)
                            .stroke(countdown.theme.tint(countdown.accent), style: StrokeStyle(lineWidth: 9 * scale, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 7 * scale) {
                            Text(state.clock)
                                .font(.system(size: 66 * scale, weight: .light, design: .rounded))
                                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.35)
                            Text(state.isFinished ? "Time’s up" : "remaining")
                                .font(.system(size: max(11, 13 * scale)))
                                .foregroundStyle(countdown.theme.secondary)
                        }
                        .padding(.horizontal, 23 * scale)
                    }
                    .frame(width: diameter, height: diameter)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(state.isFinished ? "Timer finished" : "\(state.clock) remaining")
                    Spacer(minLength: 8 * scale)
                    if state.isFinished {
                        Button(action: acknowledge) {
                            Label("Acknowledge", systemImage: "checkmark")
                                .font(.system(size: max(12, 13 * scale), weight: .medium))
                                .padding(.horizontal, 18).padding(.vertical, 10)
                                .contentShape(Rectangle())
                                .background(countdown.theme.tint(countdown.accent), in: Capsule())
                                .foregroundStyle(countdown.theme.background)
                        }
                        .buttonStyle(.plain).keyboardShortcut(.defaultAction)
                        .help("Stop the chime and remove this timer")
                    } else {
                        Text("Ends at \(timer.endsAt.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: max(10, 12 * scale)))
                            .foregroundStyle(countdown.theme.secondary)
                    }
                }
                .padding(.top, max(24, 32 * scale))
                .padding(.bottom, max(18, 34 * scale))
                .frame(maxWidth: .infinity)
            }
            .foregroundStyle(countdown.theme.foreground)
        }
    }
}
