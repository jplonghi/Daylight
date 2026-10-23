// Compiled with the app's real countdown views by render-gallery.sh.
import AppKit
import SwiftUI

@main
struct RenderGallery {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let now = LocalDay(year: 2026, month: 10, day: 22).date().addingTimeInterval(10 * 3600)
        let examples: [(String, CountdownStyle, PalettePreset, Int)] = [
            ("Our next adventure", .number, .dune, 24),
            ("A fresh start", .ring, .ember, 60),
            ("The big celebration", .flip, .porcelain, 12),
            ("A year of possibility", .grid, .grove, 100)
        ]
        let content = VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .firstTextBaseline) {
                Text("Every occasion, your way.").font(.system(size: 32, weight: .semibold, design: .rounded))
                Spacer()
                Text("daylight").font(.system(size: 22, weight: .semibold, design: .rounded)).foregroundStyle(Design.orange)
            }
            Text("Four countdown styles. Colors that feel like you.")
                .font(.system(size: 16)).foregroundStyle(Design.muted)
            LazyVGrid(columns: [GridItem(.fixed(440)), GridItem(.fixed(440))], spacing: 24) {
                ForEach(examples.indices, id: \.self) { index in
                    let example = examples[index]
                    let countdown = makeCountdown(example, now: now)
                    VStack(alignment: .leading, spacing: 10) {
                        CountdownFace(countdown: countdown, now: now)
                            .frame(width: 440, height: 350)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Design.line))
                        Text(example.1.title).font(.system(size: 14, weight: .medium)).padding(.leading, 4)
                    }
                }
            }
        }
        .padding(40).frame(width: 984).background(Design.canvas).foregroundStyle(Design.ink)
        .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let cg = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
            fatalError("Could not render countdown gallery")
        }
        try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    }

    static func makeCountdown(_ example: (String, CountdownStyle, PalettePreset, Int), now: Date) -> Countdown {
        var value = Countdown(now: now)
        value.title = example.0
        value.style = example.1
        example.2.apply(to: &value)
        value.started = LocalDay(Calendar.current.date(byAdding: .day, value: -40, to: now)!)
        value.target = LocalDay(Calendar.current.date(byAdding: .day, value: example.3, to: now)!)
        return value
    }
}
