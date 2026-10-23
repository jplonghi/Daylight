import SwiftUI
import DaylightCore

struct DayGridView: View {
    let countdown: Countdown
    let now: Date
    let scale: Double

    var body: some View {
        let state = countdown.dayGrid(at: now)
        VStack(spacing: 8) {
            Canvas { context, size in
                let columns = min(state.cellCount, max(1, Int(ceil(sqrt(Double(state.cellCount) * size.width / max(1, size.height))))))
                let rows = (state.cellCount + columns - 1) / columns
                let pitch = min(size.width / Double(columns), size.height / Double(rows), max(14, min(28, 21 * scale)))
                let gap = max(1, pitch * 0.22)
                let side = max(0.5, pitch - gap)
                let origin = CGPoint(x: (size.width - Double(columns) * pitch + gap) / 2,
                                     y: (size.height - Double(rows) * pitch + gap) / 2)
                let tint = countdown.theme.tint(countdown.accent)
                for cell in 0..<state.cellCount {
                    let rect = CGRect(x: origin.x + Double(cell % columns) * pitch,
                                      y: origin.y + Double(cell / columns) * pitch, width: side, height: side)
                    let path = Path(roundedRect: rect, cornerRadius: min(2.5, side * 0.16))
                    context.fill(path, with: .color(countdown.theme.foreground.opacity(0.085)))
                    let fraction = state.completion(of: cell)
                    if fraction > 0 {
                        context.fill(path, with: .color(tint.opacity(0.25 + fraction * 0.75)))
                    }
                    if state.currentCell == cell {
                        let line = max(1, min(1.5, side * 0.14))
                        let outline = Path(roundedRect: rect.insetBy(dx: line / 2, dy: line / 2), cornerRadius: min(2.5, side * 0.16))
                        context.stroke(outline, with: .color(tint), lineWidth: line)
                    }
                }
            }
            if state.daysPerCell > 1 {
                Text("Up to \(state.daysPerCell) days per square")
                    .font(.system(size: max(9, 10 * scale)))
                    .foregroundStyle(countdown.theme.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(state.elapsedDays) of \(state.totalDays) days passed. Each square represents up to \(state.daysPerCell) days.")
    }
}
