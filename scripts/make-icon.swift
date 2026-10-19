#!/usr/bin/env swift
// Renders a 1024x1024 App Store icon from a few parameters, no design tools needed.
//
//   swift scripts/make-icon.swift --out <path.png> --glyph capsule-check --bg 4A55A2 --bg2 7B6BE0 [--glyph-color FFFFFF] [--badge 34C759]
//
// Glyphs (all drawn with CoreGraphics paths, no SF Symbols, which Apple's license forbids in icons):
//   capsule-check   a tilted capsule with a check badge (dose taken)
//   clipboard-check a clipboard with a check (inspection, log)
//   timer-ring      a ring with a thick arc (timers, wear-time)
//   ruler-tape      a curved tape (measurements)
//   drop            a drop with a check (fluids, donations)
//   drop-dollar     a drop with a dollar sign (paid donations)
//   drop-ledger     a ruled ledger card with a drop and dollar sign in front (paid donations, earnings)
//   sheet-lines     a document with lines and a check (reports, hours)
//   route           a road from a stop to a destination pin (trips, mileage)
//   tally           four strokes with a diagonal (counting, data collection)
//   steps-down      four descending bars (tapers, step-down schedules)
//   syringe         a feeding syringe with graduations (tube feeding, fluids)
//   syringe-drop    a feeding syringe beside a drop (tube feeding; two elements)
//   two-cards       a task card with a check, an arrow, and a reward card with a star (first-then boards)
//   thermo-log      a thermometer in front of a ticked clipboard log (temperature and compliance logs)
//   hat-ring        a hard hat inside a progress ring (trade hours, apprenticeship progress)
//   card-stack      a fanned stack of cards with a flame badge (certifications, fire and EMS)
//   sheet-heart     a ruled page with a heart pinned to the corner (care summaries, handovers)
//   gauge-board     a pressure gauge in front of a clipboard (field testing, readings and reports)
//   chimney-brush   a brick stack with a sweep's rod brush in the flue (chimney work)
//   trap-dipstick   a grease interceptor in section with a graduated dipstick (FOG, tanks with layers)
//   tank-record     a buried tank with riser lids in front of a record card (septic, buried assets)
//   boiler-flame    a riveted boiler drum over its fire, with a sight glass (boilers, pressure vessels)
//   door-label      a rated door holding back flame, with its label on the hinge edge (fire doors, openings)
//   crane-hook      a lattice boom with the hook block hanging from it (cranes, lifting, rigging)
//   bag-drop        a graduated solution bag with a drop below it (dialysis, infusions, fluids)
//   signed-month    a calendar month with an ink signature across it and a seal (sign-off, approval)
//   pump-gauge      a spiral fire pump volute with a flanged discharge, a gauge mounted in front (fire pumps)
// The background is a diagonal gradient from --bg (bottom-right) to --bg2 (top-left).
// --no-bg leaves it transparent, which is what an Android adaptive-icon foreground layer needs.
// Apple applies the rounded mask itself, so the PNG is a full square with no transparency.

import AppKit
import CoreGraphics
import Foundation

func arg(_ name: String, _ fallback: String) -> String {
    let args = CommandLine.arguments
    if let i = args.firstIndex(of: name), i + 1 < args.count { return args[i + 1] }
    return fallback
}

func color(_ hex: String) -> CGColor {
    var h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
    let v = UInt32(h, radix: 16) ?? 0
    return CGColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}

let out = arg("--out", "AppIcon.png")
let glyph = arg("--glyph", "capsule-check")

/// Which of the three icons iOS asks for is being rendered.
///   light   the App Store and default home-screen icon. Opaque, full background, no alpha anywhere.
///   dark    iOS 18+ dark appearance. The glyph alone on transparency; iOS supplies the dark ground
///           behind it, so painting our own would double up and read as a sticker.
///   tinted  iOS 18+ tinted appearance. Greyscale on transparency; iOS maps luminance onto the
///           user's chosen tint, so hue is thrown away and only the light-to-dark structure survives.
let appearance = arg("--appearance", "light")
if !["light", "dark", "tinted"].contains(appearance) {
    fatalError("--appearance must be light, dark or tinted (got \(appearance))")
}

let bgBase = color(arg("--bg", "4A55A2"))   // bottom-right of the background gradient
let bgTop = color(arg("--bg2", "7B6BE0"))   // top-left of the background gradient
let size: CGFloat = 1024

func grey(_ v: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(srgbRed: v, green: v, blue: v, alpha: a) }
func white(_ a: CGFloat) -> CGColor { CGColor(srgbRed: 1, green: 1, blue: 1, alpha: a) }
func black(_ a: CGFloat) -> CGColor { CGColor(srgbRed: 0, green: 0, blue: 0, alpha: a) }

// --no-bg is the Android adaptive-icon foreground layer: light palette, no background.
let noBG = CommandLine.arguments.contains("--no-bg")
let transparent = noBG || appearance != "light"

// The three colours every glyph function draws with. Tinted throws hue away up front rather than
// desaturating at the end, so the contrast between glyph, detail and badge is chosen deliberately
// instead of being whatever the luminance of the brand colours happened to collapse to.
let glyphColor = appearance == "tinted" ? grey(1.0) : color(arg("--glyph-color", "FFFFFF"))
let badgeColor = appearance == "tinted" ? grey(0.72) : color(arg("--badge", "34C759"))
/// Glyph functions use `bg1` for the detail *inside* the glyph (a clipboard's clip, a boom's
/// lattice). In light it matches the background so the detail reads as a cut-out; on transparency
/// there is no background to match, so it stays the brand colour and carries the identity instead.
let bg1 = appearance == "tinted" ? grey(0.30) : bgBase

let space = CGColorSpace(name: CGColorSpace.sRGB)!

/// Glyphs are drawn into their own transparent layer, never straight onto the background. That is
/// what lets the material pass below shade only the glyph (blend mode .sourceAtop), and it is the
/// same code path for all three appearances — the only difference is what gets composited under it.
guard let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8,
                          bytesPerRow: 0, space: space,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("Could not create context")
}


func shadow(_ on: Bool) {
    if on { ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 36, color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.22)) }
    else { ctx.setShadow(offset: .zero, blur: 0, color: nil) }
}

func checkBadge(center: CGPoint, radius: CGFloat) {
    shadow(true)
    ctx.setFillColor(badgeColor)
    ctx.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    shadow(false)
    // white ring
    ctx.setStrokeColor(glyphColor)
    ctx.setLineWidth(radius * 0.16)
    ctx.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2).insetBy(dx: radius * 0.08, dy: radius * 0.08))
    // check
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.setLineWidth(radius * 0.22)
    ctx.move(to: CGPoint(x: center.x - radius * 0.42, y: center.y - radius * 0.02))
    ctx.addLine(to: CGPoint(x: center.x - radius * 0.1, y: center.y - radius * 0.34))
    ctx.addLine(to: CGPoint(x: center.x + radius * 0.46, y: center.y + radius * 0.3))
    ctx.strokePath()
}

func capsuleCheck() {
    let length: CGFloat = 560, width: CGFloat = 250
    ctx.saveGState()
    ctx.translateBy(x: size / 2 - 30, y: size / 2 + 30)
    ctx.rotate(by: .pi / 4)
    let rect = CGRect(x: -length / 2, y: -width / 2, width: length, height: width)
    let path = CGPath(roundedRect: rect, cornerWidth: width / 2, cornerHeight: width / 2, transform: nil)
    shadow(true)
    ctx.setFillColor(glyphColor)
    ctx.addPath(path)
    ctx.fillPath()
    shadow(false)
    // second half in a translucent tint of the background
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    ctx.setFillColor(bg1.copy(alpha: 0.55)!)
    ctx.fill(CGRect(x: 0, y: -width / 2, width: length / 2, height: width))
    ctx.restoreGState()
    // seam
    ctx.setStrokeColor(bg1.copy(alpha: 0.35)!)
    ctx.setLineWidth(10)
    ctx.move(to: CGPoint(x: 0, y: -width / 2))
    ctx.addLine(to: CGPoint(x: 0, y: width / 2))
    ctx.strokePath()
    ctx.restoreGState()
    checkBadge(center: CGPoint(x: size * 0.72, y: size * 0.27), radius: 118)
}

func clipboardCheck() {
    let board = CGRect(x: 262, y: 170, width: 500, height: 640)
    shadow(true)
    ctx.setFillColor(glyphColor)
    ctx.addPath(CGPath(roundedRect: board, cornerWidth: 56, cornerHeight: 56, transform: nil))
    ctx.fillPath()
    shadow(false)
    // clip at the top
    ctx.setFillColor(bg1)
    ctx.addPath(CGPath(roundedRect: CGRect(x: 412, y: 760, width: 200, height: 90), cornerWidth: 30, cornerHeight: 30, transform: nil))
    ctx.fillPath()
    // lines
    ctx.setStrokeColor(bg1.copy(alpha: 0.5)!)
    ctx.setLineCap(.round)
    ctx.setLineWidth(34)
    for y in [640, 540, 440] as [CGFloat] {
        ctx.move(to: CGPoint(x: 340, y: y))
        ctx.addLine(to: CGPoint(x: y == 440 ? 560 : 680, y: y))
        ctx.strokePath()
    }
    checkBadge(center: CGPoint(x: 700, y: 260), radius: 118)
}

func timerRing() {
    let center = CGPoint(x: size / 2, y: size / 2 - 10)
    shadow(true)
    ctx.setStrokeColor(glyphColor.copy(alpha: 0.35)!)
    ctx.setLineWidth(92)
    ctx.addArc(center: center, radius: 300, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.strokePath()
    shadow(false)
    ctx.setStrokeColor(glyphColor)
    ctx.setLineCap(.round)
    ctx.setLineWidth(92)
    ctx.addArc(center: center, radius: 300, startAngle: .pi / 2, endAngle: -.pi * 0.9, clockwise: true)
    ctx.strokePath()
    ctx.setFillColor(glyphColor)
    ctx.fillEllipse(in: CGRect(x: center.x - 40, y: center.y - 40, width: 80, height: 80))
    ctx.setLineWidth(44)
    ctx.move(to: center)
    ctx.addLine(to: CGPoint(x: center.x + 150, y: center.y + 110))
    ctx.strokePath()
}

func rulerTape() {
    shadow(true)
    ctx.setStrokeColor(glyphColor)
    ctx.setLineCap(.round)
    ctx.setLineWidth(150)
    ctx.move(to: CGPoint(x: 190, y: 330))
    ctx.addCurve(to: CGPoint(x: 834, y: 690), control1: CGPoint(x: 330, y: 760), control2: CGPoint(x: 700, y: 260))
    ctx.strokePath()
    shadow(false)
    ctx.setStrokeColor(bg1)
    ctx.setLineWidth(18)
    ctx.setLineCap(.round)
    let pts: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [(300, 440, 300, 500), (420, 512, 420, 560), (540, 520, 540, 580), (660, 500, 660, 548), (770, 560, 770, 620)]
    for p in pts { ctx.move(to: CGPoint(x: p.0, y: p.1)); ctx.addLine(to: CGPoint(x: p.2, y: p.3)); ctx.strokePath() }
}

func drop() {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 512, y: 880))
    path.addCurve(to: CGPoint(x: 232, y: 400), control1: CGPoint(x: 400, y: 700), control2: CGPoint(x: 232, y: 560))
    path.addArc(center: CGPoint(x: 512, y: 400), radius: 280, startAngle: .pi, endAngle: 0, clockwise: false)
    path.addCurve(to: CGPoint(x: 512, y: 880), control1: CGPoint(x: 792, y: 560), control2: CGPoint(x: 624, y: 700))
    path.closeSubpath()
    shadow(true)
    ctx.setFillColor(glyphColor)
    ctx.addPath(path)
    ctx.fillPath()
    shadow(false)
    checkBadge(center: CGPoint(x: 740, y: 250), radius: 118)
}

func dropPath(cx: CGFloat, top: CGFloat, r: CGFloat) -> CGPath {
    // A teardrop: point at the top, circle of radius r whose center sits 1.7r below the point.
    let cy = top - 1.7 * r
    let path = CGMutablePath()
    path.move(to: CGPoint(x: cx, y: top))
    path.addCurve(to: CGPoint(x: cx - r, y: cy), control1: CGPoint(x: cx - 0.4 * r, y: top - 0.65 * r), control2: CGPoint(x: cx - r, y: cy + 0.55 * r))
    path.addArc(center: CGPoint(x: cx, y: cy), radius: r, startAngle: .pi, endAngle: 0, clockwise: false)
    path.addCurve(to: CGPoint(x: cx, y: top), control1: CGPoint(x: cx + r, y: cy + 0.55 * r), control2: CGPoint(x: cx + 0.4 * r, y: top - 0.65 * r))
    path.closeSubpath()
    return path
}

func text(_ string: String, size fontSize: CGFloat, weight: NSFont.Weight, color: CGColor, center: CGPoint) {
    let font = NSFont.systemFont(ofSize: fontSize, weight: weight)
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(cgColor: color)!]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes))
    let bounds = CTLineGetBoundsWithOptions(line, [.useGlyphPathBounds])
    ctx.saveGState()
    ctx.textPosition = CGPoint(x: center.x - bounds.midX, y: center.y - bounds.midY)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

/// A ledger card with ruled lines behind a drop that carries a dollar sign (paid plasma donation).
func dropLedger() {
    let card = CGRect(x: 300, y: 130, width: 560, height: 680)
    shadow(true)
    ctx.setFillColor(glyphColor.copy(alpha: 0.92)!)
    ctx.addPath(CGPath(roundedRect: card, cornerWidth: 56, cornerHeight: 56, transform: nil))
    ctx.fillPath()
    shadow(false)
    ctx.setStrokeColor(bg1.copy(alpha: 0.35)!)
    ctx.setLineCap(.round)
    ctx.setLineWidth(30)
    for y in [700, 600, 500, 400, 300] as [CGFloat] {
        ctx.move(to: CGPoint(x: 560, y: y))
        ctx.addLine(to: CGPoint(x: 790, y: y))
        ctx.strokePath()
    }
    ctx.setLineWidth(22)
    ctx.setStrokeColor(bg1.copy(alpha: 0.55)!)
    ctx.move(to: CGPoint(x: 560, y: 220)); ctx.addLine(to: CGPoint(x: 790, y: 220)); ctx.strokePath()
    // The drop overlaps the card's left edge so the two read as one object.
    let drop = dropPath(cx: 372, top: 900, r: 210)
    shadow(true)
    ctx.setFillColor(bg1)
    ctx.addPath(drop); ctx.fillPath()
    shadow(false)
    ctx.setStrokeColor(glyphColor)
    ctx.setLineWidth(26)
    ctx.addPath(drop); ctx.strokePath()
    text("$", size: 300, weight: .heavy, color: glyphColor, center: CGPoint(x: 372, y: 520))
}

/// A single large drop with a dollar sign inside.
func dropDollar() {
    let drop = dropPath(cx: 512, top: 930, r: 290)
    shadow(true)
    ctx.setFillColor(glyphColor)
    ctx.addPath(drop); ctx.fillPath()
    shadow(false)
    text("$", size: 400, weight: .heavy, color: bg1, center: CGPoint(x: 512, y: 420))
}

/// A road between two stops with a location pin at the destination (trips, mileage).
func route() {
    shadow(true)
    ctx.setStrokeColor(glyphColor)
    ctx.setLineCap(.round)
    ctx.setLineWidth(70)
    ctx.setLineDash(phase: 0, lengths: [0.1, 130])
    ctx.move(to: CGPoint(x: 230, y: 250))
    ctx.addCurve(to: CGPoint(x: 720, y: 690), control1: CGPoint(x: 560, y: 230), control2: CGPoint(x: 380, y: 720))
    ctx.strokePath()
    ctx.setLineDash(phase: 0, lengths: [])
    // Start stop
    ctx.setFillColor(glyphColor)
    ctx.fillEllipse(in: CGRect(x: 150, y: 170, width: 160, height: 160))
    shadow(false)
    ctx.setFillColor(bg1)
    ctx.fillEllipse(in: CGRect(x: 200, y: 220, width: 60, height: 60))
    // Destination pin
    shadow(true)
    let pin = CGMutablePath()
    pin.move(to: CGPoint(x: 720, y: 560))
    pin.addCurve(to: CGPoint(x: 580, y: 780), control1: CGPoint(x: 660, y: 640), control2: CGPoint(x: 580, y: 690))
    pin.addArc(center: CGPoint(x: 720, y: 780), radius: 140, startAngle: .pi, endAngle: 0, clockwise: true)
    pin.addCurve(to: CGPoint(x: 720, y: 560), control1: CGPoint(x: 860, y: 690), control2: CGPoint(x: 780, y: 640))
    pin.closeSubpath()
    ctx.setFillColor(glyphColor)
    ctx.addPath(pin); ctx.fillPath()
    shadow(false)
    ctx.setFillColor(bg1)
    ctx.fillEllipse(in: CGRect(x: 665, y: 725, width: 110, height: 110))
}

/// Four tally strokes with a diagonal across them (counting, data collection).
func tally() {
    shadow(true)
    ctx.setStrokeColor(glyphColor)
    ctx.setLineCap(.round)
    ctx.setLineWidth(66)
    let top: CGFloat = 740, bottom: CGFloat = 300
    for i in 0..<4 {
        let x = 250 + CGFloat(i) * 145
        ctx.move(to: CGPoint(x: x, y: bottom))
        ctx.addLine(to: CGPoint(x: x, y: top))
    }
    ctx.strokePath()
    ctx.setLineWidth(62)
    ctx.move(to: CGPoint(x: 200, y: bottom + 60))
    ctx.addLine(to: CGPoint(x: 735, y: top - 60))
    ctx.strokePath()
    shadow(false)
}

/// Four bars descending left to right, like a step-down schedule.
func stepsDown() {
    shadow(true)
    ctx.setFillColor(glyphColor)
    let heights: [CGFloat] = [620, 480, 350, 250]
    let width: CGFloat = 150, gap: CGFloat = 32
    let totalWidth = width * 4 + gap * 3
    var x = (1024 - totalWidth) / 2
    for h in heights {
        let rect = CGRect(x: x, y: 230, width: width, height: h)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 34, cornerHeight: 34, transform: nil))
        ctx.fillPath()
        x += width + gap
    }
    shadow(false)
}

/// A feeding syringe: barrel with graduations, tip and plunger (tube feeding).
func syringe() {
    shadow(true)
    ctx.setFillColor(glyphColor)
    // Barrel
    ctx.addPath(CGPath(roundedRect: CGRect(x: 370, y: 210, width: 284, height: 520), cornerWidth: 40, cornerHeight: 40, transform: nil))
    ctx.fillPath()
    // Tip below the barrel
    ctx.addPath(CGPath(roundedRect: CGRect(x: 472, y: 120, width: 80, height: 110), cornerWidth: 30, cornerHeight: 30, transform: nil))
    ctx.fillPath()
    // Plunger rod and flange above it
    ctx.addPath(CGPath(roundedRect: CGRect(x: 472, y: 700, width: 80, height: 150), cornerWidth: 26, cornerHeight: 26, transform: nil))
    ctx.fillPath()
    ctx.addPath(CGPath(roundedRect: CGRect(x: 350, y: 820, width: 324, height: 70), cornerWidth: 34, cornerHeight: 34, transform: nil))
    ctx.fillPath()
    shadow(false)
    // Graduation marks cut into the barrel
    ctx.setStrokeColor(bg1)
    ctx.setLineCap(.round)
    ctx.setLineWidth(26)
    for y in [330, 430, 530, 630] as [CGFloat] {
        ctx.move(to: CGPoint(x: 430, y: y))
        ctx.addLine(to: CGPoint(x: 560, y: y))
        ctx.strokePath()
    }
}

/// A feeding syringe with a drop beside it: two elements so the icon does not read as a single shape.
func syringeDrop() {
    shadow(true)
    ctx.setFillColor(glyphColor)
    ctx.addPath(CGPath(roundedRect: CGRect(x: 210, y: 300, width: 250, height: 440), cornerWidth: 36, cornerHeight: 36, transform: nil))
    ctx.fillPath()
    ctx.addPath(CGPath(roundedRect: CGRect(x: 300, y: 218, width: 70, height: 100), cornerWidth: 26, cornerHeight: 26, transform: nil))
    ctx.fillPath()
    ctx.addPath(CGPath(roundedRect: CGRect(x: 300, y: 715, width: 70, height: 130), cornerWidth: 24, cornerHeight: 24, transform: nil))
    ctx.fillPath()
    ctx.addPath(CGPath(roundedRect: CGRect(x: 195, y: 820, width: 280, height: 62), cornerWidth: 30, cornerHeight: 30, transform: nil))
    ctx.fillPath()
    let drop = dropPath(cx: 700, top: 690, r: 165)
    ctx.addPath(drop)
    ctx.fillPath()
    shadow(false)
    ctx.setStrokeColor(bg1)
    ctx.setLineCap(.round)
    ctx.setLineWidth(24)
    for y in [400, 490, 580, 670] as [CGFloat] {
        ctx.move(to: CGPoint(x: 265, y: y))
        ctx.addLine(to: CGPoint(x: 380, y: y))
        ctx.strokePath()
    }
    ctx.setFillColor(bg1)
    ctx.fillEllipse(in: CGRect(x: 655, y: 385, width: 90, height: 90))
}

func starPath(center: CGPoint, outer: CGFloat, inner: CGFloat) -> CGPath {
    let path = CGMutablePath()
    for i in 0..<10 {
        let radius = i % 2 == 0 ? outer : inner
        let angle = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5
        let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y - sin(angle) * radius)
        if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
    }
    path.closeSubpath()
    return path
}

/// Two board cards: the task on the left with a check, the reward on the right with a star,
/// and an arrow between them. Three elements, so the icon still reads at 40 points.
func twoCards() {
    let cardWidth: CGFloat = 336, cardHeight: CGFloat = 430
    let top = size / 2 + cardHeight / 2
    let left = CGRect(x: 92, y: top - cardHeight, width: cardWidth, height: cardHeight)
    let right = CGRect(x: size - 92 - cardWidth, y: top - cardHeight, width: cardWidth, height: cardHeight)

    for card in [left, right] {
        shadow(true)
        ctx.setFillColor(glyphColor)
        ctx.addPath(CGPath(roundedRect: card, cornerWidth: 58, cornerHeight: 58, transform: nil))
        ctx.fillPath()
        shadow(false)
    }

    // The task card carries a check.
    ctx.setStrokeColor(badgeColor)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.setLineWidth(58)
    let checkCenter = CGPoint(x: left.midX, y: left.midY)
    ctx.move(to: CGPoint(x: checkCenter.x - 96, y: checkCenter.y + 8))
    ctx.addLine(to: CGPoint(x: checkCenter.x - 26, y: checkCenter.y - 66))
    ctx.addLine(to: CGPoint(x: checkCenter.x + 100, y: checkCenter.y + 80))
    ctx.strokePath()

    // The reward card carries a star.
    ctx.setFillColor(bg1)
    ctx.addPath(starPath(center: CGPoint(x: right.midX, y: right.midY), outer: 128, inner: 54))
    ctx.fillPath()

    // Arrow from one to the other.
    ctx.setStrokeColor(glyphColor)
    ctx.setLineWidth(34)
    let y = size / 2
    ctx.move(to: CGPoint(x: left.maxX + 34, y: y))
    ctx.addLine(to: CGPoint(x: right.minX - 34, y: y))
    ctx.strokePath()
    ctx.move(to: CGPoint(x: right.minX - 86, y: y + 46))
    ctx.addLine(to: CGPoint(x: right.minX - 34, y: y))
    ctx.addLine(to: CGPoint(x: right.minX - 86, y: y - 46))
    ctx.strokePath()

    // Caption strips under each card so the pair reads as a board, not two buttons.
    ctx.setFillColor(glyphColor.copy(alpha: 0.55)!)
    for card in [left, right] {
        ctx.addPath(CGPath(roundedRect: CGRect(x: card.minX + 52, y: card.minY - 74, width: cardWidth - 104, height: 40),
                           cornerWidth: 20, cornerHeight: 20, transform: nil))
        ctx.fillPath()
    }
}

/// A thermometer beside a clipboard log with a tick: the reading and the record it lands on.
func thermoLog() {
    // The clipboard behind, offset right.
    let board = CGRect(x: 404, y: 196, width: 440, height: 580)
    shadow(true)
    ctx.setFillColor(glyphColor)
    ctx.addPath(CGPath(roundedRect: board, cornerWidth: 52, cornerHeight: 52, transform: nil))
    ctx.fillPath()
    shadow(false)

    // Clip at the top of the board.
    ctx.setFillColor(bg1)
    ctx.addPath(CGPath(roundedRect: CGRect(x: board.midX - 86, y: board.maxY - 42, width: 172, height: 62),
                       cornerWidth: 26, cornerHeight: 26, transform: nil))
    ctx.fillPath()

    // Ruled lines, with the last one ticked.
    ctx.setFillColor(bg1.copy(alpha: 0.28)!)
    var lineY = board.maxY - 150
    for _ in 0..<3 {
        ctx.addPath(CGPath(roundedRect: CGRect(x: board.minX + 62, y: lineY, width: board.width - 190, height: 30),
                           cornerWidth: 15, cornerHeight: 15, transform: nil))
        ctx.fillPath()
        lineY -= 86
    }
    ctx.setStrokeColor(badgeColor)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.setLineWidth(34)
    ctx.move(to: CGPoint(x: board.minX + 74, y: lineY + 18))
    ctx.addLine(to: CGPoint(x: board.minX + 126, y: lineY - 26))
    ctx.addLine(to: CGPoint(x: board.minX + 228, y: lineY + 76))
    ctx.strokePath()

    // The thermometer in front, on the left.
    let stemWidth: CGFloat = 96
    let bulbRadius: CGFloat = 88
    let cx: CGFloat = 258
    let bulbY: CGFloat = 284
    shadow(true)
    ctx.setFillColor(glyphColor)
    ctx.fillEllipse(in: CGRect(x: cx - bulbRadius, y: bulbY - bulbRadius, width: bulbRadius * 2, height: bulbRadius * 2))
    ctx.addPath(CGPath(roundedRect: CGRect(x: cx - stemWidth / 2, y: bulbY, width: stemWidth, height: 456),
                       cornerWidth: stemWidth / 2, cornerHeight: stemWidth / 2, transform: nil))
    ctx.fillPath()
    shadow(false)

    // The mercury inside, and graduation marks down the right of the stem.
    ctx.setFillColor(badgeColor)
    ctx.fillEllipse(in: CGRect(x: cx - 56, y: bulbY - 56, width: 112, height: 112))
    ctx.addPath(CGPath(roundedRect: CGRect(x: cx - 26, y: bulbY, width: 52, height: 300),
                       cornerWidth: 26, cornerHeight: 26, transform: nil))
    ctx.fillPath()

    ctx.setStrokeColor(bg1.copy(alpha: 0.55)!)
    ctx.setLineWidth(14)
    var markY = bulbY + 220
    for _ in 0..<4 {
        ctx.move(to: CGPoint(x: cx + 12, y: markY))
        ctx.addLine(to: CGPoint(x: cx + 34, y: markY))
        ctx.strokePath()
        markY += 62
    }
}

/// A hard hat inside a progress ring: the trade and the hours, two elements that read at any size.
func hatRing() {
    let centre = CGPoint(x: size / 2, y: size / 2)
    let ringRadius: CGFloat = 338
    let lineWidth: CGFloat = 78

    // Track, then the filled arc from the top round to about three quarters.
    ctx.setLineCap(.round)
    ctx.setStrokeColor(glyphColor.copy(alpha: 0.26)!)
    ctx.setLineWidth(lineWidth)
    ctx.addArc(center: centre, radius: ringRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.strokePath()

    ctx.setStrokeColor(badgeColor)
    ctx.setLineWidth(lineWidth)
    ctx.addArc(center: centre, radius: ringRadius, startAngle: .pi / 2, endAngle: -.pi / 3, clockwise: true)
    ctx.strokePath()

    // The hat: a dome with its flat side down, on a brim that overhangs it.
    let domeBase: CGFloat = centre.y - 34
    let domeRadius: CGFloat = 168
    let brimHeight: CGFloat = 58
    let brimWidth: CGFloat = 466

    shadow(true)
    ctx.setFillColor(glyphColor)
    ctx.move(to: CGPoint(x: centre.x - domeRadius, y: domeBase))
    ctx.addArc(center: CGPoint(x: centre.x, y: domeBase), radius: domeRadius,
               startAngle: .pi, endAngle: 0, clockwise: true)
    ctx.closePath()
    ctx.fillPath()
    ctx.addPath(CGPath(roundedRect: CGRect(x: centre.x - brimWidth / 2, y: domeBase - brimHeight,
                                           width: brimWidth, height: brimHeight),
                       cornerWidth: brimHeight / 2, cornerHeight: brimHeight / 2, transform: nil))
    ctx.fillPath()
    shadow(false)

    // Two ridges over the crown so it reads as a hard hat.
    ctx.setStrokeColor(bg1.copy(alpha: 0.42)!)
    ctx.setLineWidth(20)
    ctx.setLineCap(.round)
    for offset in [CGFloat(-66), CGFloat(66)] {
        ctx.move(to: CGPoint(x: centre.x + offset * 1.12, y: domeBase + 18))
        ctx.addCurve(to: CGPoint(x: centre.x + offset * 0.34, y: domeBase + domeRadius - 20),
                     control1: CGPoint(x: centre.x + offset * 1.08, y: domeBase + 96),
                     control2: CGPoint(x: centre.x + offset * 0.72, y: domeBase + domeRadius - 62))
        ctx.strokePath()
    }
}

/// A stack of cards with a flame badge: the wallet of certifications and the trade it belongs to.
func cardStack() {
    let cx = size / 2
    // Two cards behind, fanned, then the front card square on.
    func roundedCard(_ rect: CGRect, rotation: CGFloat, alpha: CGFloat) {
        ctx.saveGState()
        ctx.translateBy(x: rect.midX, y: rect.midY)
        ctx.rotate(by: rotation)
        ctx.translateBy(x: -rect.midX, y: -rect.midY)
        shadow(true)
        ctx.setFillColor(glyphColor.copy(alpha: alpha)!)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 46, cornerHeight: 46, transform: nil))
        ctx.fillPath()
        shadow(false)
        ctx.restoreGState()
    }

    let front = CGRect(x: cx - 300, y: 300, width: 600, height: 392)
    roundedCard(front, rotation: 0.16, alpha: 0.5)
    roundedCard(front, rotation: 0.08, alpha: 0.72)
    roundedCard(front, rotation: 0, alpha: 1)

    // Ruled lines on the front card, the way a licence reads.
    ctx.setFillColor(bg1.copy(alpha: 0.26)!)
    var lineY = front.maxY - 132
    for width in [CGFloat(300), CGFloat(232), CGFloat(176)] {
        ctx.addPath(CGPath(roundedRect: CGRect(x: front.minX + 60, y: lineY, width: width, height: 30),
                           cornerWidth: 15, cornerHeight: 15, transform: nil))
        ctx.fillPath()
        lineY -= 66
    }

    // The flame badge, sitting on the lower right corner of the stack.
    let centre = CGPoint(x: front.maxX - 48, y: front.minY + 36)
    let radius: CGFloat = 128
    shadow(true)
    ctx.setFillColor(badgeColor)
    ctx.fillEllipse(in: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
    shadow(false)

    // A flame, not a drop: the difference is asymmetry. A leaning tip, a bulge on one side,
    // a concave sweep on the other and a second small tongue. A symmetric teardrop reads as water.
    ctx.setFillColor(glyphColor)
    let tip = CGPoint(x: centre.x + 6, y: centre.y + 86)
    let path = CGMutablePath()
    path.move(to: tip)
    path.addCurve(to: CGPoint(x: centre.x + 50, y: centre.y - 18),
                  control1: CGPoint(x: centre.x + 52, y: centre.y + 30),
                  control2: CGPoint(x: centre.x + 58, y: centre.y + 4))
    path.addCurve(to: CGPoint(x: centre.x - 14, y: centre.y - 64),
                  control1: CGPoint(x: centre.x + 44, y: centre.y - 54),
                  control2: CGPoint(x: centre.x + 10, y: centre.y - 70))
    path.addCurve(to: CGPoint(x: centre.x - 40, y: centre.y + 10),
                  control1: CGPoint(x: centre.x - 50, y: centre.y - 54),
                  control2: CGPoint(x: centre.x - 58, y: centre.y - 14))
    path.addCurve(to: CGPoint(x: centre.x - 38, y: centre.y + 56),
                  control1: CGPoint(x: centre.x - 28, y: centre.y + 28),
                  control2: CGPoint(x: centre.x - 30, y: centre.y + 42))
    path.addCurve(to: tip,
                  control1: CGPoint(x: centre.x - 12, y: centre.y + 42),
                  control2: CGPoint(x: centre.x - 2, y: centre.y + 62))
    path.closeSubpath()
    ctx.addPath(path)
    ctx.fillPath()

    // The hot core, low and offset, in the badge colour.
    ctx.setFillColor(badgeColor)
    let inner = CGMutablePath()
    let innerTip = CGPoint(x: centre.x + 2, y: centre.y + 20)
    inner.move(to: innerTip)
    inner.addCurve(to: CGPoint(x: centre.x + 24, y: centre.y - 26),
                   control1: CGPoint(x: centre.x + 20, y: centre.y - 2),
                   control2: CGPoint(x: centre.x + 26, y: centre.y - 12))
    inner.addCurve(to: CGPoint(x: centre.x - 20, y: centre.y - 24),
                   control1: CGPoint(x: centre.x + 20, y: centre.y - 48),
                   control2: CGPoint(x: centre.x - 18, y: centre.y - 48))
    inner.addCurve(to: innerTip,
                   control1: CGPoint(x: centre.x - 22, y: centre.y - 6),
                   control2: CGPoint(x: centre.x - 10, y: centre.y + 4))
    inner.closeSubpath()
    ctx.addPath(inner)
    ctx.fillPath()
}

/// A sheet of paper with a heart pinned to it: the page, and who it is for.
func sheetHeart() {
    let page = CGRect(x: 254, y: 208, width: 516, height: 636)
    shadow(true)
    ctx.setFillColor(glyphColor)
    ctx.addPath(CGPath(roundedRect: page, cornerWidth: 48, cornerHeight: 48, transform: nil))
    ctx.fillPath()
    shadow(false)

    // Ruled lines, the top one short like a heading and the rest full width.
    ctx.setFillColor(bg1.copy(alpha: 0.24)!)
    var lineY = page.maxY - 150
    let widths: [CGFloat] = [200, 356, 356, 300, 356, 248]
    for width in widths {
        ctx.addPath(CGPath(roundedRect: CGRect(x: page.minX + 78, y: lineY, width: width, height: 28),
                           cornerWidth: 14, cornerHeight: 14, transform: nil))
        ctx.fillPath()
        lineY -= 74
    }

    // The heart, overlapping the lower right corner so it reads as pinned on rather than printed.
    let centre = CGPoint(x: page.maxX - 26, y: page.minY + 52)
    let r: CGFloat = 132
    shadow(true)
    ctx.setFillColor(badgeColor)
    let heart = CGMutablePath()
    let bottom = CGPoint(x: centre.x, y: centre.y - r * 0.78)
    heart.move(to: bottom)
    heart.addCurve(to: CGPoint(x: centre.x - r, y: centre.y + r * 0.24),
                   control1: CGPoint(x: centre.x - r * 0.62, y: centre.y - r * 0.30),
                   control2: CGPoint(x: centre.x - r, y: centre.y - r * 0.06))
    heart.addArc(center: CGPoint(x: centre.x - r * 0.5, y: centre.y + r * 0.26),
                 radius: r * 0.5, startAngle: .pi, endAngle: 0, clockwise: true)
    heart.addArc(center: CGPoint(x: centre.x + r * 0.5, y: centre.y + r * 0.26),
                 radius: r * 0.5, startAngle: .pi, endAngle: 0, clockwise: true)
    heart.addCurve(to: bottom,
                   control1: CGPoint(x: centre.x + r, y: centre.y - r * 0.06),
                   control2: CGPoint(x: centre.x + r * 0.62, y: centre.y - r * 0.30))
    heart.closeSubpath()
    ctx.addPath(heart)
    ctx.fillPath()
    shadow(false)
}

/// A pressure gauge in front of a clipboard: the reading and the report it lands on.
func gaugeBoard() {
    // The clipboard, offset back and right.
    let board = CGRect(x: 372, y: 198, width: 470, height: 596)
    shadow(true)
    ctx.setFillColor(glyphColor.copy(alpha: 0.92)!)
    ctx.addPath(CGPath(roundedRect: board, cornerWidth: 50, cornerHeight: 50, transform: nil))
    ctx.fillPath()
    shadow(false)
    ctx.setFillColor(bg1)
    ctx.addPath(CGPath(roundedRect: CGRect(x: board.midX - 84, y: board.maxY - 40, width: 168, height: 58),
                       cornerWidth: 25, cornerHeight: 25, transform: nil))
    ctx.fillPath()
    ctx.setFillColor(bg1.copy(alpha: 0.24)!)
    var lineY = board.maxY - 150
    for width in [CGFloat(250), CGFloat(300), CGFloat(190)] {
        ctx.addPath(CGPath(roundedRect: CGRect(x: board.minX + 54, y: lineY, width: width, height: 28),
                           cornerWidth: 14, cornerHeight: 14, transform: nil))
        ctx.fillPath()
        lineY -= 80
    }

    // The gauge, in front and to the left.
    let centre = CGPoint(x: 372, y: 392)
    let outer: CGFloat = 226
    shadow(true)
    ctx.setFillColor(glyphColor)
    ctx.fillEllipse(in: CGRect(x: centre.x - outer, y: centre.y - outer, width: outer * 2, height: outer * 2))
    shadow(false)
    ctx.setFillColor(bg1.copy(alpha: 0.14)!)
    ctx.fillEllipse(in: CGRect(x: centre.x - outer + 34, y: centre.y - outer + 34,
                               width: (outer - 34) * 2, height: (outer - 34) * 2))

    // Tick marks around the dial.
    ctx.setStrokeColor(bg1.copy(alpha: 0.55)!)
    ctx.setLineCap(.round)
    ctx.setLineWidth(15)
    for step in 0...8 {
        let angle = CGFloat.pi * 1.25 - CGFloat(step) * (.pi * 1.5 / 8)
        let inner = outer - 88, out = outer - 52
        ctx.move(to: CGPoint(x: centre.x + cos(angle) * inner, y: centre.y + sin(angle) * inner))
        ctx.addLine(to: CGPoint(x: centre.x + cos(angle) * out, y: centre.y + sin(angle) * out))
        ctx.strokePath()
    }

    // The needle, pointing up and right into the healthy part of the dial.
    ctx.setStrokeColor(badgeColor)
    ctx.setLineWidth(26)
    let needle = CGFloat.pi * 0.42
    ctx.move(to: CGPoint(x: centre.x, y: centre.y))
    ctx.addLine(to: CGPoint(x: centre.x + cos(needle) * (outer - 86),
                            y: centre.y + sin(needle) * (outer - 86)))
    ctx.strokePath()
    ctx.setFillColor(badgeColor)
    ctx.fillEllipse(in: CGRect(x: centre.x - 34, y: centre.y - 34, width: 68, height: 68))
}

func sheetLines() {
    let sheet = CGRect(x: 262, y: 150, width: 500, height: 700)
    shadow(true)
    ctx.setFillColor(glyphColor)
    ctx.addPath(CGPath(roundedRect: sheet, cornerWidth: 48, cornerHeight: 48, transform: nil))
    ctx.fillPath()
    shadow(false)
    ctx.setStrokeColor(bg1.copy(alpha: 0.5)!)
    ctx.setLineCap(.round)
    ctx.setLineWidth(34)
    for (i, y) in ([720, 620, 520, 420] as [CGFloat]).enumerated() {
        ctx.move(to: CGPoint(x: 340, y: y))
        ctx.addLine(to: CGPoint(x: i == 3 ? 540 : 684, y: y))
        ctx.strokePath()
    }
    checkBadge(center: CGPoint(x: 700, y: 250), radius: 118)
}

/// A brick chimney stack with a sweep's rod brush going down the flue.
func chimneyBrush() {
    let stack = CGRect(x: 250, y: 96, width: 360, height: 470)
    shadow(true)
    ctx.setFillColor(glyphColor)
    ctx.addPath(CGPath(roundedRect: stack, cornerWidth: 24, cornerHeight: 24, transform: nil))
    ctx.fillPath()
    let crown = CGRect(x: 208, y: 556, width: 444, height: 70)
    ctx.addPath(CGPath(roundedRect: crown, cornerWidth: 20, cornerHeight: 20, transform: nil))
    ctx.fillPath()
    shadow(false)

    // Brick courses, staggered the way they are actually laid.
    ctx.setStrokeColor(bg1.copy(alpha: 0.30)!)
    ctx.setLineWidth(13)
    var courseY = stack.minY + 72
    var stagger = false
    while courseY < stack.maxY - 24 {
        ctx.move(to: CGPoint(x: stack.minX + 20, y: courseY))
        ctx.addLine(to: CGPoint(x: stack.maxX - 20, y: courseY))
        ctx.strokePath()
        let joint = stagger ? stack.midX - 90 : stack.midX + 90
        ctx.move(to: CGPoint(x: joint, y: courseY))
        ctx.addLine(to: CGPoint(x: joint, y: min(courseY + 84, stack.maxY - 24)))
        ctx.strokePath()
        courseY += 84
        stagger.toggle()
    }

    // The flue, dark, so the brush is visibly going into something.
    ctx.setFillColor(bg1.copy(alpha: 0.72)!)
    ctx.addPath(CGPath(roundedRect: CGRect(x: stack.midX - 88, y: crown.minY - 34, width: 176, height: 104),
                       cornerWidth: 18, cornerHeight: 18, transform: nil))
    ctx.fillPath()

    // The rod and its brush head, drawn along one axis so the bristles sit across the
    // rod rather than radiating from a point.
    ctx.saveGState()
    ctx.translateBy(x: stack.midX, y: crown.minY + 26)
    ctx.rotate(by: -.pi / 5)
    ctx.setStrokeColor(badgeColor)
    ctx.setLineCap(.round)
    ctx.setLineWidth(30)
    ctx.move(to: .zero)
    ctx.addLine(to: CGPoint(x: 0, y: 372))
    ctx.strokePath()

    ctx.setStrokeColor(glyphColor)
    ctx.setLineWidth(16)
    var along: CGFloat = 112
    while along <= 300 {
        ctx.move(to: CGPoint(x: -118, y: along))
        ctx.addLine(to: CGPoint(x: 118, y: along))
        ctx.strokePath()
        along += 40
    }
    ctx.setFillColor(badgeColor)
    ctx.addPath(CGPath(roundedRect: CGRect(x: -26, y: 88, width: 52, height: 236),
                       cornerWidth: 26, cornerHeight: 26, transform: nil))
    ctx.fillPath()
    ctx.restoreGState()
}

/// A grease interceptor in section, with the dipstick that measures it.
func trapDipstick() {
    let tank = CGRect(x: 150, y: 250, width: 640, height: 470)
    shadow(true)
    ctx.setFillColor(glyphColor)
    ctx.addPath(CGPath(roundedRect: tank, cornerWidth: 44, cornerHeight: 44, transform: nil))
    ctx.fillPath()
    shadow(false)

    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: tank, cornerWidth: 44, cornerHeight: 44, transform: nil))
    ctx.clip()
    // The grease cap floating on top, and the sludge that settles under it: the two
    // layers the quarter rule adds together.
    ctx.setFillColor(badgeColor)
    ctx.fill(CGRect(x: tank.minX, y: tank.maxY - 126, width: tank.width, height: 126))
    ctx.setFillColor(bg1.copy(alpha: 0.30)!)
    ctx.fill(CGRect(x: tank.minX, y: tank.minY, width: tank.width, height: 92))
    // Inlet and outlet tees.
    ctx.setStrokeColor(bg1.copy(alpha: 0.72)!)
    ctx.setLineWidth(38)
    ctx.setLineCap(.butt)
    for x in [tank.minX + 104, tank.maxX - 104] {
        ctx.move(to: CGPoint(x: x, y: tank.maxY))
        ctx.addLine(to: CGPoint(x: x, y: tank.minY + 120))
        ctx.strokePath()
    }
    ctx.restoreGState()
    // A rim, so the tank reads as a container rather than a striped card.
    ctx.setStrokeColor(bg1.copy(alpha: 0.55)!)
    ctx.setLineWidth(18)
    ctx.addPath(CGPath(roundedRect: tank.insetBy(dx: 9, dy: 9), cornerWidth: 36, cornerHeight: 36, transform: nil))
    ctx.strokePath()

    // The dipstick, pushed down through the grease, graduated like a sludge judge.
    ctx.saveGState()
    ctx.translateBy(x: 690, y: 540)
    ctx.rotate(by: -.pi / 14)
    shadow(true)
    ctx.setFillColor(glyphColor)
    let stick = CGPath(roundedRect: CGRect(x: -36, y: -330, width: 72, height: 680),
                       cornerWidth: 36, cornerHeight: 36, transform: nil)
    ctx.addPath(stick)
    ctx.fillPath()
    shadow(false)
    ctx.setStrokeColor(bg1.copy(alpha: 0.55)!)
    ctx.setLineWidth(14)
    ctx.addPath(stick)
    ctx.strokePath()
    ctx.setStrokeColor(bg1.copy(alpha: 0.65)!)
    ctx.setLineCap(.round)
    ctx.setLineWidth(12)
    var tick: CGFloat = -250
    var long = true
    while tick < 300 {
        ctx.move(to: CGPoint(x: -22, y: tick))
        ctx.addLine(to: CGPoint(x: long ? 24 : 2, y: tick))
        ctx.strokePath()
        tick += 58
        long.toggle()
    }
    ctx.restoreGState()
}

/// A septic tank in section, in front of the card its record is kept on.
func tankRecord() {
    // The record card, behind and to the right.
    let card = CGRect(x: 420, y: 230, width: 430, height: 560)
    shadow(true)
    ctx.setFillColor(glyphColor.copy(alpha: 0.84)!)
    ctx.addPath(CGPath(roundedRect: card, cornerWidth: 46, cornerHeight: 46, transform: nil))
    ctx.fillPath()
    shadow(false)
    ctx.setFillColor(badgeColor)
    ctx.addPath(CGPath(roundedRect: CGRect(x: card.minX, y: card.maxY - 96, width: card.width, height: 96),
                       cornerWidth: 46, cornerHeight: 46, transform: nil))
    ctx.fillPath()
    ctx.fill(CGRect(x: card.minX, y: card.maxY - 110, width: card.width, height: 60))
    ctx.setFillColor(bg1.copy(alpha: 0.22)!)
    var lineY = card.maxY - 190
    for width in [CGFloat(250), CGFloat(300), CGFloat(210), CGFloat(280)] {
        ctx.addPath(CGPath(roundedRect: CGRect(x: card.minX + 46, y: lineY, width: width, height: 26),
                           cornerWidth: 13, cornerHeight: 13, transform: nil))
        ctx.fillPath()
        lineY -= 74
    }

    // The ground the tank is buried in, so the lids read as the only part you ever see.
    ctx.setFillColor(bg1.copy(alpha: 0.35)!)
    ctx.fill(CGRect(x: 0, y: 560, width: size, height: 26))

    // The tank, in front and to the left, with two risers breaking that line.
    let tank = CGRect(x: 96, y: 210, width: 480, height: 330)
    shadow(true)
    ctx.setFillColor(glyphColor)
    ctx.addPath(CGPath(roundedRect: tank, cornerWidth: 46, cornerHeight: 46, transform: nil))
    ctx.fillPath()
    shadow(false)
    ctx.setStrokeColor(bg1.copy(alpha: 0.45)!)
    ctx.setLineWidth(16)
    ctx.addPath(CGPath(roundedRect: tank.insetBy(dx: 8, dy: 8), cornerWidth: 38, cornerHeight: 38, transform: nil))
    ctx.strokePath()
    for x in [tank.minX + 116, tank.maxX - 116] {
        ctx.setFillColor(glyphColor)
        ctx.addPath(CGPath(roundedRect: CGRect(x: x - 58, y: tank.maxY - 20, width: 116, height: 130),
                           cornerWidth: 16, cornerHeight: 16, transform: nil))
        ctx.fillPath()
        shadow(true)
        ctx.setFillColor(badgeColor)
        ctx.addPath(CGPath(roundedRect: CGRect(x: x - 82, y: tank.maxY + 96, width: 164, height: 46),
                           cornerWidth: 23, cornerHeight: 23, transform: nil))
        ctx.fillPath()
        shadow(false)
    }

    // Liquid level, and the sludge on the floor of the tank.
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: tank, cornerWidth: 46, cornerHeight: 46, transform: nil))
    ctx.clip()
    ctx.setFillColor(bg1.copy(alpha: 0.22)!)
    ctx.fill(CGRect(x: tank.minX, y: tank.minY, width: tank.width, height: 196))
    ctx.setFillColor(bg1.copy(alpha: 0.40)!)
    ctx.fill(CGRect(x: tank.minX, y: tank.minY, width: tank.width, height: 76))
    ctx.restoreGState()
}

/// A boiler drum over its fire, with the sight glass the operator reads every shift.
/// Deliberately nothing like gauge-board: Backflow Log already owns the gauge-on-clipboard.
func boilerFlame() {
    let drum = CGRect(x: 262, y: 330, width: 392, height: 462)

    // The fire, drawn first so the drum's underside clips the tips of the tallest tongue.
    func flame(cx: CGFloat, base: CGFloat, height: CGFloat, width: CGFloat, colour: CGColor) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: cx - width / 2, y: base))
        path.addQuadCurve(to: CGPoint(x: cx, y: base + height),
                          control: CGPoint(x: cx - width * 0.70, y: base + height * 0.70))
        path.addQuadCurve(to: CGPoint(x: cx + width / 2, y: base),
                          control: CGPoint(x: cx + width * 0.70, y: base + height * 0.70))
        path.closeSubpath()
        ctx.setFillColor(colour)
        ctx.addPath(path)
        ctx.fillPath()
    }
    let inner = CGColor(srgbRed: 1, green: 0.83, blue: 0.35, alpha: 1)
    flame(cx: 330, base: 118, height: 176, width: 104, colour: badgeColor)
    flame(cx: 586, base: 118, height: 158, width: 96, colour: badgeColor)
    flame(cx: 458, base: 110, height: 236, width: 132, colour: badgeColor)
    flame(cx: 458, base: 118, height: 132, width: 66, colour: inner)

    // Legs, so the drum stands over the fire instead of sitting in it.
    ctx.setFillColor(glyphColor)
    for x in [drum.minX + 64, drum.maxX - 118] {
        ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: 262, width: 54, height: 110),
                           cornerWidth: 20, cornerHeight: 20, transform: nil))
        ctx.fillPath()
    }

    // The steam outlet on top.
    ctx.addPath(CGPath(roundedRect: CGRect(x: drum.midX - 46, y: drum.maxY - 30, width: 92, height: 96),
                       cornerWidth: 22, cornerHeight: 22, transform: nil))
    ctx.fillPath()
    ctx.addPath(CGPath(roundedRect: CGRect(x: drum.midX - 74, y: drum.maxY + 50, width: 148, height: 40),
                       cornerWidth: 20, cornerHeight: 20, transform: nil))
    ctx.fillPath()

    // The shell.
    shadow(true)
    ctx.setFillColor(glyphColor)
    ctx.addPath(CGPath(roundedRect: drum, cornerWidth: 68, cornerHeight: 68, transform: nil))
    ctx.fillPath()
    shadow(false)

    // Riveted seams, and the manhole door between them.
    ctx.setStrokeColor(bg1.copy(alpha: 0.26)!)
    ctx.setLineWidth(14)
    for y in [drum.minY + 96, drum.maxY - 96] {
        ctx.move(to: CGPoint(x: drum.minX + 16, y: y))
        ctx.addLine(to: CGPoint(x: drum.maxX - 16, y: y))
        ctx.strokePath()
    }
    let door = CGPoint(x: drum.midX, y: drum.midY)
    ctx.setStrokeColor(bg1.copy(alpha: 0.40)!)
    ctx.setLineWidth(18)
    ctx.strokeEllipse(in: CGRect(x: door.x - 78, y: door.y - 78, width: 156, height: 156))

    // The sight glass, standing clear of the shell so it reads as its own tube.
    let glass = CGRect(x: 730, y: 388, width: 70, height: 348)
    ctx.setStrokeColor(glyphColor)
    ctx.setLineCap(.round)
    ctx.setLineWidth(22)
    for y in [glass.minY + 74, glass.maxY - 74] {
        ctx.move(to: CGPoint(x: drum.maxX - 34, y: y))
        ctx.addLine(to: CGPoint(x: glass.midX, y: y))
        ctx.strokePath()
    }
    shadow(true)
    ctx.setFillColor(glyphColor)
    ctx.addPath(CGPath(roundedRect: glass, cornerWidth: 37, cornerHeight: 37, transform: nil))
    ctx.fillPath()
    shadow(false)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: glass.insetBy(dx: 16, dy: 16), cornerWidth: 21, cornerHeight: 21, transform: nil))
    ctx.clip()
    ctx.setFillColor(badgeColor)
    ctx.fill(CGRect(x: glass.minX, y: glass.minY, width: glass.width, height: 152))
    ctx.restoreGState()
}

/// A rated door holding back the fire, with its label on the hinge edge.
/// The label is the whole point: an assembly whose label cannot be read is not a rated assembly.
func doorLabel() {
    // The fire behind, so the door is visibly doing its job. The tip leans, because a
    // symmetrical teardrop reads as a leaf rather than a flame.
    func flame(cx: CGFloat, base: CGFloat, height: CGFloat, width: CGFloat, lean: CGFloat, colour: CGColor) {
        let apex = CGPoint(x: cx + lean, y: base + height)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: cx - width / 2, y: base))
        path.addCurve(to: apex,
                      control1: CGPoint(x: cx - width * 0.62, y: base + height * 0.46),
                      control2: CGPoint(x: cx - width * 0.30, y: base + height * 0.86))
        path.addCurve(to: CGPoint(x: cx + width / 2, y: base),
                      control1: CGPoint(x: cx + width * 0.46, y: base + height * 0.72),
                      control2: CGPoint(x: cx + width * 0.60, y: base + height * 0.30))
        path.closeSubpath()
        ctx.setFillColor(colour)
        ctx.addPath(path)
        ctx.fillPath()
    }
    let inner = CGColor(srgbRed: 1, green: 0.78, blue: 0.30, alpha: 1)
    flame(cx: 690, base: 148, height: 520, width: 310, lean: -46, colour: badgeColor)
    flame(cx: 700, base: 170, height: 330, width: 176, lean: -26, colour: inner)

    // The door slab, sitting in front of it.
    let door = CGRect(x: 168, y: 120, width: 392, height: 760)
    shadow(true)
    ctx.setFillColor(glyphColor)
    ctx.addPath(CGPath(roundedRect: door, cornerWidth: 26, cornerHeight: 26, transform: nil))
    ctx.fillPath()
    shadow(false)

    // Two recessed panels, which is what a door reads as at any size.
    ctx.setStrokeColor(bg1.copy(alpha: 0.26)!)
    ctx.setLineWidth(15)
    for rect in [CGRect(x: door.minX + 58, y: door.midY + 40, width: door.width - 116, height: 264),
                 CGRect(x: door.minX + 58, y: door.minY + 64, width: door.width - 116, height: 264)] {
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 16, cornerHeight: 16, transform: nil))
        ctx.strokePath()
    }

    // Lever handle on the leading edge.
    ctx.setFillColor(bg1.copy(alpha: 0.55)!)
    ctx.fillEllipse(in: CGRect(x: door.maxX - 92, y: door.midY - 34, width: 68, height: 68))
    ctx.addPath(CGPath(roundedRect: CGRect(x: door.maxX - 124, y: door.midY - 14, width: 84, height: 28),
                       cornerWidth: 14, cornerHeight: 14, transform: nil))
    ctx.fillPath()

    // The rating label, riveted to the hinge edge near the top.
    let label = CGRect(x: door.minX + 40, y: door.maxY - 188, width: 150, height: 96)
    shadow(true)
    ctx.setFillColor(badgeColor)
    ctx.addPath(CGPath(roundedRect: label, cornerWidth: 18, cornerHeight: 18, transform: nil))
    ctx.fillPath()
    shadow(false)
    ctx.setStrokeColor(glyphColor)
    ctx.setLineCap(.round)
    ctx.setLineWidth(14)
    var y = label.maxY - 30
    for width in [CGFloat(86), CGFloat(62)] {
        ctx.move(to: CGPoint(x: label.minX + 26, y: y))
        ctx.addLine(to: CGPoint(x: label.minX + 26 + width, y: y))
        ctx.strokePath()
        y -= 34
    }
}

/// A lattice boom with the hook block hanging off it — the two things anyone recognises
/// about a crane, and nothing that another app in this portfolio already uses.
func craneHook() {
    // The carrier, with the counterweight behind the cab.
    let body = CGRect(x: 120, y: 170, width: 300, height: 190)
    shadow(true)
    ctx.setFillColor(glyphColor)
    ctx.addPath(CGPath(roundedRect: body, cornerWidth: 32, cornerHeight: 32, transform: nil))
    ctx.fillPath()
    shadow(false)
    // Tracks under it.
    ctx.setFillColor(bg1.copy(alpha: 0.45)!)
    ctx.addPath(CGPath(roundedRect: CGRect(x: body.minX - 16, y: body.minY - 46, width: body.width + 32, height: 60),
                       cornerWidth: 30, cornerHeight: 30, transform: nil))
    ctx.fillPath()
    // Cab window.
    ctx.setFillColor(bg1.copy(alpha: 0.30)!)
    ctx.addPath(CGPath(roundedRect: CGRect(x: body.minX + 40, y: body.minY + 54, width: 104, height: 92),
                       cornerWidth: 20, cornerHeight: 20, transform: nil))
    ctx.fillPath()

    // The boom, rising to the upper right.
    ctx.saveGState()
    ctx.translateBy(x: 330, y: 340)
    ctx.rotate(by: -.pi / 3.4)
    let boom = CGRect(x: -46, y: 0, width: 92, height: 560)
    shadow(true)
    ctx.setFillColor(glyphColor)
    ctx.addPath(CGPath(roundedRect: boom, cornerWidth: 26, cornerHeight: 26, transform: nil))
    ctx.fillPath()
    shadow(false)
    // Lattice: the zig-zag that says crane rather than pole.
    ctx.setStrokeColor(bg1.copy(alpha: 0.34)!)
    ctx.setLineWidth(13)
    ctx.setLineCap(.round)
    var along: CGFloat = 46
    var flip = false
    while along < boom.height - 46 {
        ctx.move(to: CGPoint(x: flip ? -26 : 26, y: along))
        ctx.addLine(to: CGPoint(x: flip ? 26 : -26, y: along + 62))
        ctx.strokePath()
        along += 62
        flip.toggle()
    }
    ctx.restoreGState()

    // The hoist line and the hook block, hanging plumb from the boom tip.
    let tip = CGPoint(x: 330 + sin(CGFloat.pi / 3.4) * 560, y: 340 + cos(CGFloat.pi / 3.4) * 560)
    ctx.setStrokeColor(glyphColor)
    ctx.setLineWidth(16)
    ctx.move(to: CGPoint(x: tip.x, y: tip.y))
    ctx.addLine(to: CGPoint(x: tip.x, y: 430))
    ctx.strokePath()

    shadow(true)
    ctx.setFillColor(badgeColor)
    ctx.addPath(CGPath(roundedRect: CGRect(x: tip.x - 62, y: 330, width: 124, height: 104),
                       cornerWidth: 26, cornerHeight: 26, transform: nil))
    ctx.fillPath()
    shadow(false)
    // The hook itself, a J under the block.
    ctx.setStrokeColor(badgeColor)
    ctx.setLineWidth(28)
    ctx.setLineCap(.round)
    let hook = CGMutablePath()
    hook.move(to: CGPoint(x: tip.x, y: 330))
    hook.addLine(to: CGPoint(x: tip.x, y: 258))
    hook.addArc(center: CGPoint(x: tip.x - 44, y: 258), radius: 44,
                startAngle: 0, endAngle: .pi * 1.15, clockwise: false)
    ctx.addPath(hook)
    ctx.strokePath()
}

/// A solution bag with a drop under it — a dialysis bag rather than a drip stand, because the
/// buyer here is a patient doing this at their own kitchen table.
func bagDrop() {
    // The hanger loop.
    ctx.setStrokeColor(glyphColor)
    ctx.setLineWidth(30)
    ctx.setLineCap(.round)
    ctx.addEllipse(in: CGRect(x: 470, y: 852, width: 84, height: 84))
    ctx.strokePath()

    // The bag.
    let bag = CGRect(x: 288, y: 392, width: 448, height: 490)
    shadow(true)
    ctx.setFillColor(glyphColor)
    ctx.addPath(CGPath(roundedRect: bag, cornerWidth: 64, cornerHeight: 64, transform: nil))
    ctx.fillPath()
    shadow(false)

    // The fluid inside it, filled from the bottom.
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: bag.insetBy(dx: 26, dy: 26), cornerWidth: 44, cornerHeight: 44, transform: nil))
    ctx.clip()
    ctx.setFillColor(badgeColor)
    ctx.fill(CGRect(x: bag.minX, y: bag.minY, width: bag.width, height: 300))
    ctx.restoreGState()

    // Graduation ticks up the left edge, which is what makes it a measured bag.
    ctx.setStrokeColor(bg1.copy(alpha: 0.45)!)
    ctx.setLineWidth(14)
    var tick = bag.minY + 88
    var long = true
    while tick < bag.maxY - 70 {
        ctx.move(to: CGPoint(x: bag.minX + 52, y: tick))
        ctx.addLine(to: CGPoint(x: bag.minX + (long ? 128 : 96), y: tick))
        ctx.strokePath()
        tick += 74
        long.toggle()
    }

    // The port and the line running down out of it.
    ctx.setFillColor(glyphColor)
    ctx.addPath(CGPath(roundedRect: CGRect(x: bag.midX - 38, y: bag.minY - 74, width: 76, height: 96),
                       cornerWidth: 26, cornerHeight: 26, transform: nil))
    ctx.fillPath()
    ctx.setStrokeColor(glyphColor)
    ctx.setLineWidth(20)
    ctx.move(to: CGPoint(x: bag.midX, y: bag.minY - 62))
    ctx.addLine(to: CGPoint(x: bag.midX, y: 232))
    ctx.strokePath()

    // The drop.
    let tip = CGPoint(x: bag.midX, y: 92)
    let drop = CGMutablePath()
    drop.move(to: CGPoint(x: tip.x, y: tip.y + 152))
    drop.addCurve(to: CGPoint(x: tip.x + 76, y: tip.y + 46),
                  control1: CGPoint(x: tip.x + 34, y: tip.y + 112),
                  control2: CGPoint(x: tip.x + 76, y: tip.y + 88))
    drop.addArc(center: CGPoint(x: tip.x, y: tip.y + 46), radius: 76,
                startAngle: 0, endAngle: .pi, clockwise: true)
    drop.addCurve(to: CGPoint(x: tip.x, y: tip.y + 152),
                  control1: CGPoint(x: tip.x - 76, y: tip.y + 88),
                  control2: CGPoint(x: tip.x - 34, y: tip.y + 112))
    drop.closeSubpath()
    shadow(true)
    ctx.setFillColor(badgeColor)
    ctx.addPath(drop)
    ctx.fillPath()
    shadow(false)
}

/// A month, signed.
///
/// The whole product is one idea: hours do not count until a supervisor signs the month. So
/// the icon is a month — a calendar grid — with a real ink signature written across it, and a
/// seal to say it was accepted. The signature deliberately runs off the edge of the card,
/// because that is what a hand does and a printed form does not.
func signedMonth() {
    let card = CGRect(x: 152, y: 238, width: 690, height: 560)

    shadow(true)
    ctx.setFillColor(glyphColor)
    ctx.addPath(CGPath(roundedRect: card, cornerWidth: 56, cornerHeight: 56, transform: nil))
    ctx.fillPath()
    shadow(false)

    // The binding strip along the top, which is what makes a card read as a calendar.
    ctx.setFillColor(bg1.copy(alpha: 0.92)!)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: card, cornerWidth: 56, cornerHeight: 56, transform: nil))
    ctx.clip()
    ctx.fill(CGRect(x: card.minX, y: card.maxY - 92, width: card.width, height: 92))
    ctx.restoreGState()
    // Two rings through it.
    ctx.setFillColor(glyphColor)
    for x in [card.minX + 168, card.maxX - 168] {
        ctx.fillEllipse(in: CGRect(x: x - 26, y: card.maxY - 66, width: 52, height: 52))
    }

    // The month itself: seven columns, two rows of days.
    ctx.setFillColor(bg1.copy(alpha: 0.22)!)
    let columns = 7, rows = 2
    let gridLeft = card.minX + 54, gridRight = card.maxX - 54
    let cell = (gridRight - gridLeft - CGFloat(columns - 1) * 14) / CGFloat(columns)
    var rowTop = card.maxY - 150
    for _ in 0..<rows {
        for column in 0..<columns {
            let x = gridLeft + CGFloat(column) * (cell + 14)
            ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: rowTop - cell, width: cell, height: cell),
                               cornerWidth: 13, cornerHeight: 13, transform: nil))
            ctx.fillPath()
        }
        rowTop -= cell + 16
    }

    // The signature: an entry stroke, a tall closing loop the way a capital is written,
    // then three humps that shorten as the hand speeds up, and a flourish out.
    ctx.setStrokeColor(bg1)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.setLineWidth(34)
    let sign = CGMutablePath()
    sign.move(to: CGPoint(x: 206, y: 316))
    sign.addCurve(to: CGPoint(x: 296, y: 486),
                  control1: CGPoint(x: 226, y: 430), control2: CGPoint(x: 252, y: 486))
    sign.addCurve(to: CGPoint(x: 292, y: 370),
                  control1: CGPoint(x: 332, y: 486), control2: CGPoint(x: 330, y: 402))
    sign.addCurve(to: CGPoint(x: 344, y: 374),
                  control1: CGPoint(x: 258, y: 342), control2: CGPoint(x: 304, y: 330))
    sign.addCurve(to: CGPoint(x: 440, y: 386),
                  control1: CGPoint(x: 384, y: 416), control2: CGPoint(x: 406, y: 430))
    sign.addCurve(to: CGPoint(x: 516, y: 398),
                  control1: CGPoint(x: 474, y: 344), control2: CGPoint(x: 488, y: 350))
    sign.addCurve(to: CGPoint(x: 622, y: 368),
                  control1: CGPoint(x: 544, y: 446), control2: CGPoint(x: 570, y: 436))
    sign.addCurve(to: CGPoint(x: 726, y: 358),
                  control1: CGPoint(x: 662, y: 322), control2: CGPoint(x: 694, y: 330))
    ctx.addPath(sign)
    ctx.strokePath()

    // The flourish under it, lighter and stopping short of the seal.
    ctx.setStrokeColor(bg1.copy(alpha: 0.40)!)
    ctx.setLineWidth(13)
    let underline = CGMutablePath()
    underline.move(to: CGPoint(x: 250, y: 282))
    underline.addCurve(to: CGPoint(x: 676, y: 296),
                       control1: CGPoint(x: 400, y: 248), control2: CGPoint(x: 560, y: 254))
    ctx.addPath(underline)
    ctx.strokePath()

    // The seal: accepted.
    checkBadge(center: CGPoint(x: 834, y: 258), radius: 116)
}

/// A horizontal-split-case fire pump volute — the spiral casing that wraps one full turn from the
/// thin cutwater back to itself at full discharge thickness — with a pressure gauge mounted in
/// front of it, reading high. The spiral is what says "fire pump" rather than "any machine", and
/// the gauge is kept deliberately smaller and lower so it stays the instrument, not the subject:
/// Boiler Log and Backflow Log both already lead with a gauge.
func pumpGauge() {
    let center = CGPoint(x: 400, y: 560)
    let innerRadius: CGFloat = 55, outerRadius: CGFloat = 300
    let innerWidth: CGFloat = 46, outerWidth: CGFloat = 174

    // The shell: one 360-degree sweep, drawn as many short thick segments whose width grows with
    // the angle so the casing visibly widens as it wraps around — the shape a volute is actually
    // cast to, thin at the tongue and full pipe size by the time it reaches the discharge.
    shadow(true)
    ctx.setLineCap(.round)
    ctx.setStrokeColor(glyphColor)
    var angle: CGFloat = 0
    let step: CGFloat = 0.06
    while angle < .pi * 2 {
        let t = angle / (.pi * 2)
        let r = innerRadius + (outerRadius - innerRadius) * t
        let next = min(angle + step, .pi * 2)
        let tNext = next / (.pi * 2)
        let rNext = innerRadius + (outerRadius - innerRadius) * tNext
        ctx.setLineWidth(innerWidth + (outerWidth - innerWidth) * t)
        ctx.move(to: CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r))
        ctx.addLine(to: CGPoint(x: center.x + cos(next) * rNext, y: center.y + sin(next) * rNext))
        ctx.strokePath()
        angle = next
    }
    shadow(false)

    // The discharge nozzle, running straight out from where the coil closes at full thickness.
    let nozzle = CGRect(x: center.x + outerRadius, y: center.y - outerWidth / 2, width: 168, height: outerWidth)
    shadow(true)
    ctx.setFillColor(glyphColor)
    ctx.addPath(CGPath(roundedRect: nozzle, cornerWidth: 14, cornerHeight: 14, transform: nil))
    ctx.fillPath()
    shadow(false)

    // The flange plate on the nozzle's face, standing proud, with its ring of bolts.
    let flange = CGRect(x: nozzle.maxX - 4, y: center.y - outerWidth / 2 - 30, width: 46, height: outerWidth + 60)
    ctx.setFillColor(glyphColor)
    ctx.addPath(CGPath(roundedRect: flange, cornerWidth: 20, cornerHeight: 20, transform: nil))
    ctx.fillPath()
    ctx.setFillColor(bg1)
    for dy in [CGFloat(-80), -28, 28, 80] {
        ctx.fillEllipse(in: CGRect(x: flange.midX - 15, y: center.y + dy - 15, width: 30, height: 30))
    }

    // The suction eye at the middle of the coil, cut back to the interior colour with a rim of its
    // own, so the shell reads as wrapped around an opening rather than a solid disc.
    ctx.setFillColor(bg1)
    ctx.fillEllipse(in: CGRect(x: center.x - 50, y: center.y - 50, width: 100, height: 100))
    ctx.setStrokeColor(glyphColor)
    ctx.setLineWidth(10)
    ctx.strokeEllipse(in: CGRect(x: center.x - 58, y: center.y - 58, width: 116, height: 116))

    // The pressure gauge, mounted in front and kept smaller than the case it reads from — the
    // volute is the subject, the gauge is only what it is instrumented with.
    let gaugeCenter = CGPoint(x: 566, y: 296)
    let gaugeRadius: CGFloat = 128
    shadow(true)
    ctx.setFillColor(glyphColor)
    ctx.fillEllipse(in: CGRect(x: gaugeCenter.x - gaugeRadius, y: gaugeCenter.y - gaugeRadius,
                               width: gaugeRadius * 2, height: gaugeRadius * 2))
    shadow(false)
    ctx.setFillColor(bg1.copy(alpha: 0.16)!)
    ctx.fillEllipse(in: CGRect(x: gaugeCenter.x - gaugeRadius + 30, y: gaugeCenter.y - gaugeRadius + 30,
                               width: (gaugeRadius - 30) * 2, height: (gaugeRadius - 30) * 2))
    ctx.setStrokeColor(bg1.copy(alpha: 0.55)!)
    ctx.setLineCap(.round)
    ctx.setLineWidth(11)
    for tick in 0...8 {
        let a = CGFloat.pi * 1.25 - CGFloat(tick) * (.pi * 1.5 / 8)
        let innerTick = gaugeRadius - 50, outerTick = gaugeRadius - 26
        ctx.move(to: CGPoint(x: gaugeCenter.x + cos(a) * innerTick, y: gaugeCenter.y + sin(a) * innerTick))
        ctx.addLine(to: CGPoint(x: gaugeCenter.x + cos(a) * outerTick, y: gaugeCenter.y + sin(a) * outerTick))
        ctx.strokePath()
    }
    ctx.setStrokeColor(badgeColor)
    ctx.setLineWidth(16)
    let needle = CGFloat.pi * 0.38
    ctx.move(to: gaugeCenter)
    ctx.addLine(to: CGPoint(x: gaugeCenter.x + cos(needle) * (gaugeRadius - 48),
                            y: gaugeCenter.y + sin(needle) * (gaugeRadius - 48)))
    ctx.strokePath()
    ctx.setFillColor(badgeColor)
    ctx.fillEllipse(in: CGRect(x: gaugeCenter.x - 20, y: gaugeCenter.y - 20, width: 40, height: 40))
}

switch glyph {
case "capsule-check": capsuleCheck()
case "clipboard-check": clipboardCheck()
case "timer-ring": timerRing()
case "ruler-tape": rulerTape()
case "drop": drop()
case "drop-dollar": dropDollar()
case "drop-ledger": dropLedger()
case "sheet-lines": sheetLines()
case "route": route()
case "tally": tally()
case "steps-down": stepsDown()
case "syringe": syringe()
case "syringe-drop": syringeDrop()
case "two-cards": twoCards()
case "thermo-log": thermoLog()
case "hat-ring": hatRing()
case "card-stack": cardStack()
case "sheet-heart": sheetHeart()
case "gauge-board": gaugeBoard()
case "chimney-brush": chimneyBrush()
case "trap-dipstick": trapDipstick()
case "tank-record": tankRecord()
case "boiler-flame": boilerFlame()
case "door-label": doorLabel()
case "crane-hook": craneHook()
case "bag-drop": bagDrop()
case "signed-month": signedMonth()
case "pump-gauge": pumpGauge()
default: fatalError("Unknown glyph \(glyph)")
}

// ---------------------------------------------------------------------------------------------
// Material pass. Everything below is per-icon, not per-glyph: the shading is clipped to whatever
// the glyph function happened to draw, so all 30-odd glyphs gain the same depth without any of
// them being edited. .sourceAtop composites only where the layer is already opaque, which is
// exactly "inside the glyph" — no mask image, no second render.
// ---------------------------------------------------------------------------------------------
/// A flat-coloured copy of the glyph layer that keeps its alpha. Drawing this offset and then
/// compositing it back inside the glyph is what produces an edge: the offset copy covers the whole
/// shape except a band along the edges facing the offset, and that uncovered band becomes the rim.
func silhouette(_ img: CGImage, _ colour: CGColor) -> CGImage {
    guard let c = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8,
                            bytesPerRow: 0, space: space,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fatalError("Could not create the silhouette context")
    }
    c.draw(img, in: CGRect(x: 0, y: 0, width: size, height: size))
    c.setBlendMode(.sourceIn)
    c.setFillColor(colour)
    c.fill(CGRect(x: 0, y: 0, width: size, height: size))
    guard let out = c.makeImage() else { fatalError("Could not render the silhouette") }
    return out
}

/// The band along one set of edges: the silhouette minus a copy of itself pushed `dy` away.
/// `.destinationOut` erases the destination wherever the source has alpha, so the overlap is
/// removed and only the uncovered lip is left.
func rim(_ img: CGImage, dy: CGFloat, _ colour: CGColor) -> CGImage {
    let full = CGRect(x: 0, y: 0, width: size, height: size)
    guard let c = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8,
                            bytesPerRow: 0, space: space,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fatalError("Could not create the rim context")
    }
    c.draw(silhouette(img, colour), in: full)
    c.setBlendMode(.destinationOut)
    c.draw(img, in: full.offsetBy(dx: 0, dy: dy))
    guard let out = c.makeImage() else { fatalError("Could not render the rim") }
    return out
}

guard let flatGlyph = ctx.makeImage() else { fatalError("Could not read back the glyph layer") }
let shapeRect = CGRect(x: 0, y: 0, width: size, height: size)

ctx.saveGState()
ctx.setBlendMode(.sourceAtop)

// The edge. Rather than darken the whole shape to imply a bevel — which just makes the artwork
// look dirty — cut the rim out exactly: take the solid silhouette, erase the same silhouette
// shifted, and what survives is the band along the edges facing the shift. Lighting that band
// leaves the body of the glyph at full strength. Works on whatever the glyph function drew, a
// capsule or a boom or a lattice, without knowing anything about its geometry.
ctx.draw(rim(flatGlyph, dy: -10, white(0.55)), in: shapeRect)   // top edges catch the light
ctx.draw(rim(flatGlyph, dy: 9, black(0.28)), in: shapeRect)     // undersides fall into shade

// Light from above: the top of every shape lifts, the underside sinks. This is the single change
// that stops a flat fill reading as a sticker.
let lift = CGGradient(colorsSpace: space, colors: [white(0.30), white(0)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(lift, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: size * 0.42), options: [])
let sink = CGGradient(colorsSpace: space, colors: [black(0.20), black(0)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(sink, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size * 0.52), options: [])

// A specular bloom up and left, matching the background highlight so both agree about where the
// light is. Icons whose highlight and shadow disagree look wrong without the viewer knowing why.
let spec = CGGradient(colorsSpace: space, colors: [white(0.22), white(0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(spec, startCenter: CGPoint(x: size * 0.30, y: size * 0.76), startRadius: 0,
                       endCenter: CGPoint(x: size * 0.30, y: size * 0.76), endRadius: size * 0.62, options: [])
ctx.restoreGState()

guard let glyphLayer = ctx.makeImage() else { fatalError("Could not render the glyph layer") }

// ---------------------------------------------------------------------------------------------
// Compose the finished icon.
// ---------------------------------------------------------------------------------------------
let full = CGRect(x: 0, y: 0, width: size, height: size)
// The App Store icon must have no alpha channel at all, so the opaque case gets a context that
// cannot carry one. The two on-device appearances keep theirs, because iOS composites them.
guard let outCtx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8,
                             bytesPerRow: 0, space: space,
                             bitmapInfo: (transparent ? CGImageAlphaInfo.premultipliedLast
                                                      : CGImageAlphaInfo.noneSkipLast).rawValue) else {
    fatalError("Could not create the output context")
}

/// Fine luminance noise. Flat gradients band on an OLED panel and read as machine-made; a little
/// grain under the glyph breaks the banding up. Drawn in soft light so it textures without
/// shifting the colour.
func grain(in target: CGContext, alpha: CGFloat) {
    let tile = 128
    var seed: UInt64 = 0x9E3779B97F4A7C15
    var bytes = [UInt8](repeating: 0, count: tile * tile * 4)
    for i in 0..<(tile * tile) {
        seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
        let v = UInt8(112 + Int(seed % 32))
        bytes[i * 4] = v; bytes[i * 4 + 1] = v; bytes[i * 4 + 2] = v; bytes[i * 4 + 3] = 255
    }
    guard let provider = CGDataProvider(data: Data(bytes) as CFData),
          let noise = CGImage(width: tile, height: tile, bitsPerComponent: 8, bitsPerPixel: 32,
                              bytesPerRow: tile * 4, space: space,
                              bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                              provider: provider, decode: nil, shouldInterpolate: false,
                              intent: .defaultIntent) else { return }
    target.saveGState()
    target.setBlendMode(.softLight)
    target.setAlpha(alpha)
    target.draw(noise, in: full, byTiling: true)
    target.restoreGState()
}

if !transparent {
    let gradient = CGGradient(colorsSpace: space, colors: [bgTop, bgBase] as CFArray, locations: [0, 1])!
    outCtx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])

    // Lit from the top left, same direction as the glyph's specular.
    let highlight = CGGradient(colorsSpace: space, colors: [white(0.20), white(0)] as CFArray, locations: [0, 1])!
    outCtx.drawRadialGradient(highlight, startCenter: CGPoint(x: size * 0.25, y: size * 0.80), startRadius: 0,
                              endCenter: CGPoint(x: size * 0.25, y: size * 0.80), endRadius: size * 0.92, options: [])

    // A wide diagonal sheen across the upper third, well under the glyph so it never competes.
    outCtx.saveGState()
    outCtx.translateBy(x: size / 2, y: size / 2)
    outCtx.rotate(by: -.pi / 5)
    let sheen = CGGradient(colorsSpace: space, colors: [white(0), white(0.10), white(0)] as CFArray,
                           locations: [0, 0.5, 1])!
    outCtx.drawLinearGradient(sheen, start: CGPoint(x: 0, y: size * 0.10), end: CGPoint(x: 0, y: size * 0.50), options: [])
    outCtx.restoreGState()

    grain(in: outCtx, alpha: 0.40)

    // Corners fall away so the square reads as a lit surface rather than a swatch. Subtle: at 60px
    // on a home screen this is felt, not seen.
    let vignette = CGGradient(colorsSpace: space, colors: [black(0), black(0.14)] as CFArray, locations: [0.55, 1])!
    outCtx.drawRadialGradient(vignette, startCenter: CGPoint(x: size / 2, y: size / 2), startRadius: 0,
                              endCenter: CGPoint(x: size / 2, y: size / 2), endRadius: size * 0.78,
                              options: [.drawsAfterEndLocation])
}

outCtx.draw(glyphLayer, in: full)

if transparent {
    // Grain on transparency would be visible as noise in the empty area, so it is confined to the
    // glyph itself.
    outCtx.saveGState()
    outCtx.setBlendMode(.sourceAtop)
    grain(in: outCtx, alpha: 0.35)
    outCtx.restoreGState()
}

guard let image = outCtx.makeImage() else { fatalError("Could not render") }
let url = URL(fileURLWithPath: out)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { fatalError("Could not write \(out)") }
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("Could not finalize \(out)") }
print("wrote \(out)  [\(glyph), \(appearance)\(transparent ? ", alpha" : ", opaque")]")