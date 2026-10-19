import SwiftUI

/// A row of choices that wraps instead of truncating.
///
/// **Why this exists.** A segmented control divides its width evenly between its segments and
/// then ellipsises whatever does not fit, so "Fibrin strands" becomes "Fibrin stra…" and the
/// user is reading a guess. Shortening the word to fit is the same bug wearing a hat: "Def"
/// instead of "Deficiency" saves the layout and costs the reader.
///
/// These chips size to their own text and wrap to the next line when the row is full, so the
/// words are always whole at any width, in any dynamic type size, in any language.
///
///     ChoiceChips(options: EffluentAppearance.allCases, selection: $appearance) { $0.name }
struct ChoiceChips<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    var title: (Value) -> String
    var tint: (Value) -> Color = { _ in .accentColor }

    var body: some View {
        Wrap(spacing: 8, lineSpacing: 8) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button { selection = option } label: {
                    Text(title(option))
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 30)
                        .background(isSelected ? tint(option).opacity(0.18) : Color(.secondarySystemFill),
                                    in: Capsule())
                        .foregroundStyle(isSelected ? tint(option) : Color.primary)
                        .overlay(
                            Capsule().strokeBorder(isSelected ? tint(option).opacity(0.55) : .clear,
                                                   lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Lays subviews left to right, starting a new line when the next one would not fit whole.
///
/// Nothing here ever proposes a narrowed width to a subview, which is what makes truncation
/// impossible: each child is measured at its natural size and placed at it.
struct Wrap: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    private func rows(_ subviews: Subviews, width: CGFloat) -> [[(Int, CGSize)]] {
        var result: [[(Int, CGSize)]] = [[]]
        var x: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if x > 0, x + spacing + size.width > width {
                result.append([])
                x = 0
            }
            result[result.count - 1].append((index, size))
            x += (x > 0 ? spacing : 0) + size.width
        }
        return result
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let width = proposal.width ?? .infinity
        let rows = rows(subviews, width: width)
        let height = rows.reduce(0) { $0 + ($1.map(\.1.height).max() ?? 0) }
            + lineSpacing * CGFloat(max(0, rows.count - 1))
        let widest = rows.map { row in
            row.reduce(0) { $0 + $1.1.width } + spacing * CGFloat(max(0, row.count - 1))
        }.max() ?? 0
        return CGSize(width: width.isFinite ? min(width, widest) : widest, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        let rows = rows(subviews, width: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map(\.1.height).max() ?? 0
            for (index, size) in row {
                subviews[index].place(at: CGPoint(x: x, y: y + (rowHeight - size.height) / 2),
                                      anchor: .topLeading,
                                      proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + lineSpacing
        }
    }
}
