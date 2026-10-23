import SwiftUI
import DaylightCore

struct CountdownFace: View {
    let countdown: Countdown
    let now: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let scale = min(size.width / 520, size.height / 440)
            let state = countdown.snapshot(at: now)
            let tint = countdown.theme.tint(countdown.accent)
            ZStack {
                countdown.theme.background
                VStack(spacing: 0) {
                    Text(countdown.displayTitle)
                        .font(.system(size: max(12, 23 * scale), weight: .medium, design: .rounded))
                        .lineLimit(2)
                        .minimumScaleFactor(0.55)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: size.width * 0.85)
                    Spacer(minLength: 10 * scale)
                    Group {
                        switch countdown.style {
                        case .number: number(state, scale: scale, width: size.width)
                        case .ring: ring(state, scale: scale, tint: tint)
                        case .flip: flip(state, scale: scale, width: size.width)
                        case .grid:
                            DayGridView(countdown: countdown, now: now, scale: scale)
                                .frame(width: size.width * 0.84, height: size.height * 0.49)
                        }
                    }
                    Spacer(minLength: 12 * scale)
                    Text(countdown.target.date().formatted(.dateTime.month(.wide).day().year()))
                        .font(.system(size: max(10, 12 * scale)))
                        .foregroundStyle(countdown.theme.secondary)
                        .frame(maxWidth: size.width * 0.85)
                }
                .padding(.horizontal, 24 * scale)
                .padding(.top, max(24, 32 * scale))
                .padding(.bottom, max(18, 34 * scale))
                .frame(maxWidth: .infinity)
            }
            .foregroundStyle(countdown.theme.foreground)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary(state))
        }
    }

    private func accessibilitySummary(_ state: CountdownSnapshot) -> String {
        let remaining: String
        if state.isToday || state.hasPassed {
            remaining = state.caption
        } else if countdown.style == .flip {
            remaining = "\(state.fullDays) days, \(state.hours) hours, \(state.minutes) minutes to go"
        } else {
            remaining = "\(state.days) \(state.caption)"
        }
        var progress = ""
        if countdown.style == .grid {
            let grid = countdown.dayGrid(at: now)
            progress = ", \(grid.elapsedDays) of \(grid.totalDays) days passed"
            if grid.daysPerCell > 1 { progress += ", up to \(grid.daysPerCell) days per square" }
        }
        return "\(countdown.displayTitle), \(remaining)\(progress), \(countdown.target.date().formatted(date: .complete, time: .omitted))"
    }

    private func number(_ state: CountdownSnapshot, scale: Double, width: Double) -> some View {
            Text(String(state.days))
                .font(.system(size: 180 * scale, weight: .light, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.2)
                .padding(.horizontal, max(6, 8 * scale))
                .frame(width: width * 0.83)
                .contentTransition(.numericText(countsDown: true))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: state.days)
    }

    private func ring(_ state: CountdownSnapshot, scale: Double, tint: Color) -> some View {
        let diameter = 252 * scale
        return ZStack {
            Circle().stroke(countdown.theme.foreground.opacity(0.09), lineWidth: 9 * scale)
            Circle()
                .trim(from: 0, to: state.remainingFraction)
                .stroke(tint, style: StrokeStyle(lineWidth: 9 * scale, lineCap: .round))
                .rotationEffect(.degrees(-90))
            ForEach(0..<60) { tick in
                Capsule()
                    .fill(countdown.theme.foreground.opacity(tick % 5 == 0 ? 0.25 : 0.10))
                    .frame(width: max(1, scale), height: (tick % 5 == 0 ? 6 : 3) * scale)
                    .offset(y: -diameter / 2 + 19 * scale)
                    .rotationEffect(.degrees(Double(tick) * 6))
            }
                Text(String(state.days))
                    .font(.system(size: 98 * scale, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.22)
                    .padding(.horizontal, max(5, 6 * scale))
                    .frame(width: diameter * 0.76)
                    .contentTransition(.numericText(countsDown: true))
        }
        .frame(width: diameter, height: diameter)
    }

    private func flip(_ state: CountdownSnapshot, scale: Double, width: Double) -> some View {
        VStack(spacing: 17 * scale) {
            HStack(alignment: .top, spacing: 11 * scale) {
                flapGroup(value: state.fullDays, label: "DAYS", scale: scale)
                flapGroup(value: state.hours, label: "HOURS", scale: scale)
                flapGroup(value: state.minutes, label: "MINUTES", scale: scale)
            }
            .frame(maxWidth: width * 0.9)
            if state.isToday || state.hasPassed {
                Text(state.caption)
                    .font(.system(size: max(11, 13 * scale)))
                    .foregroundStyle(countdown.theme.secondary)
            }
        }
    }

    private func flapGroup(value: Int, label: String, scale: Double) -> some View {
        VStack(spacing: 16 * scale) {
            FlipCard(value: value, theme: countdown.theme, scale: scale)
            Text(label)
                .font(.system(size: max(8, 9 * scale), weight: .medium))
                .tracking(2 * scale)
                .foregroundStyle(countdown.theme.secondary)
        }
    }
}

private struct FlipCard: View {
    let value: Int
    let theme: WidgetTheme
    let scale: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var previous: Int = 0
    @State private var angle: Double = 0
    @State private var turning = false

    var body: some View {
        ZStack {
            card(value)
            if turning {
                card(previous)
                    .mask(alignment: .top) { Rectangle().frame(height: 68 * scale) }
                    .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), anchor: .center, perspective: 0.45)
            }
            Rectangle().fill(theme.background.opacity(0.7)).frame(height: max(1, scale))
            HStack {
                hinge
                Spacer(minLength: 0)
                hinge
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 136 * scale)
        .onChange(of: value) { old, _ in
            guard !reduceMotion else { return }
            previous = old; angle = 0; turning = true
            withAnimation(.easeIn(duration: 0.35), completionCriteria: .logicallyComplete) {
                angle = -90
            } completion: {
                turning = false
            }
        }
    }

    private var hinge: some View {
        RoundedRectangle(cornerRadius: 2 * scale)
            .fill(theme.background)
            .frame(width: 4 * scale, height: 15 * scale)
    }

    private func card(_ number: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10 * scale)
                .fill(theme.flap)
                .overlay {
                    RoundedRectangle(cornerRadius: 10 * scale).strokeBorder(theme.foreground.opacity(0.07), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.13), radius: 2 * scale, y: 4 * scale)
            Text(String(format: "%02d", number))
                .font(.system(size: 69 * scale, weight: .medium, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.25)
                .padding(.horizontal, 5 * scale)
        }
    }
}
