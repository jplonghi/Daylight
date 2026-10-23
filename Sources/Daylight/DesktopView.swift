import SwiftUI
import DaylightCore

struct DesktopView: View {
    @ObservedObject var store: CountdownStore
    @ObservedObject var windows: AppController
    let countdownID: UUID

    var body: some View {
        if let entry = store.entry(countdownID) {
            TimelineView(.periodic(from: .now, by: entry.timer == nil ? 60 : 1)) { context in
                if let timer = entry.timer {
                    FocusTimerFace(countdown: entry.countdown, timer: timer, now: context.date) {
                        windows.acknowledgeTimer(countdownID)
                    }
                } else {
                    CountdownFace(countdown: entry.countdown, now: context.date)
                }
            }
            .preferredColorScheme(entry.countdown.theme.isDark ? .dark : .light)
            .contentShape(Rectangle())
            .contextMenu {
                Button("Open main window") { windows.edit(countdownID) }
                Button("Hide tile") { windows.hideWidget(countdownID) }
            }
            .onExitCommand { windows.exitFullScreen(countdownID) }
        }
    }
}
