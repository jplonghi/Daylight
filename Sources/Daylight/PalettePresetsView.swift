import SwiftUI
import DaylightCore

struct PalettePresetsView: View {
    let theme: WidgetTheme
    let accent: Accent
    var columns = 2
    let choose: (PalettePreset) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
            ForEach(PalettePreset.allCases, id: \.self) { preset in
                let selected = theme == preset.theme && accent == preset.accent
                Button { choose(preset) } label: {
                    HStack(spacing: 6) {
                        Circle().trim(from: 0, to: 0.76)
                            .stroke(preset.theme.tint(preset.accent), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(-90)).frame(width: 15, height: 15)
                        Text(preset.title).font(.system(size: 10, weight: .medium)).lineLimit(1)
                        Spacer(minLength: 0)
                        if selected { Image(systemName: "checkmark").font(.system(size: 8, weight: .bold)) }
                    }
                    .foregroundStyle(preset.theme.foreground)
                    .padding(.horizontal, 9).frame(height: 38).frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .background(preset.theme.background, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(selected ? Design.orange : Design.ink.opacity(0.15), lineWidth: selected ? 2 : 1)
                            .allowsHitTesting(false)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(preset.title) palette")
                .accessibilityAddTraits(selected ? .isSelected : [])
                .help("\(preset.theme.title) background · \(preset.accent.title) accent")
            }
        }
    }
}
