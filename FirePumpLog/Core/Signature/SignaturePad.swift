import SwiftUI
import UIKit

/// A signature, drawn with a finger.
///
/// An NFPA 25 test record is a signed document: the annual flow test carries the name and
/// signature of whoever ran it, and a typed name is not the whole of what an authority having
/// jurisdiction asks for. Strokes are captured as points and rendered to a PNG on save, which
/// keeps the stored image small and the drawing smooth.
///
///     @State private var signature: Data?
///     SignaturePad(data: $signature, name: "A. Reyes")
struct SignaturePad: View {
    @Binding var data: Data?
    var name: String = ""
    var height: CGFloat = 160

    @State private var strokes: [[CGPoint]] = []
    @State private var current: [CGPoint] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))

                if let data, let image = UIImage(data: data), strokes.isEmpty {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                } else {
                    Canvas { context, _ in
                        for stroke in strokes + [current] where stroke.count > 1 {
                            var path = Path()
                            path.move(to: stroke[0])
                            for point in stroke.dropFirst() { path.addLine(to: point) }
                            context.stroke(path, with: .color(.primary),
                                           style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in current.append(value.location) }
                            .onEnded { _ in
                                if current.count > 1 { strokes.append(current) }
                                current = []
                                render()
                            }
                    )
                }

                // The ruled line and the name under it, the way a paper form does it.
                VStack(alignment: .leading, spacing: 2) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.35))
                        .frame(height: 1)
                    Text(name.isEmpty ? "Signature" : name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
                .allowsHitTesting(false)
            }
            .frame(height: height)

            if data != nil || !strokes.isEmpty {
                Button("Clear signature", role: .destructive) {
                    strokes = []; current = []; data = nil
                }
                .font(.caption)
            }
        }
    }

    private func render() {
        guard !strokes.isEmpty else { data = nil; return }
        let bounds = strokes.flatMap { $0 }.reduce(into: CGRect.null) { rect, point in
            rect = rect.union(CGRect(origin: point, size: CGSize(width: 1, height: 1)))
        }.insetBy(dx: -12, dy: -12)
        guard bounds.width > 0, bounds.height > 0 else { return }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 2
        format.opaque = false
        data = UIGraphicsImageRenderer(size: bounds.size, format: format).pngData { ctx in
            ctx.cgContext.translateBy(x: -bounds.minX, y: -bounds.minY)
            ctx.cgContext.setStrokeColor(UIColor.label.cgColor)
            ctx.cgContext.setLineWidth(2.5)
            ctx.cgContext.setLineCap(.round)
            ctx.cgContext.setLineJoin(.round)
            for stroke in strokes where stroke.count > 1 {
                ctx.cgContext.move(to: stroke[0])
                for point in stroke.dropFirst() { ctx.cgContext.addLine(to: point) }
                ctx.cgContext.strokePath()
            }
        }
    }
}
