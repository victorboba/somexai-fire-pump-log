# App icons

Everything the App Store and iOS require, and the house rules for making an icon that does not look
like the other twenty apps on this account. Written down once so it does not have to be asked for
again.

## One command

```bash
scripts/make-appicon.sh <AppTarget> <glyph> <bg> <bg2> <badge>
scripts/make-appicon.sh CraneLog crane-hook 1F3A5F 3E6FA8 F2A63B
```

That renders all three appearances, writes `Contents.json`, checks the dimensions and alpha, and
runs the catalog through Xcode's own `actool`. It prints `OK` or it fails with the reason. If it
fails, the icon is not finished — do not work around it by hand-editing `Contents.json`.

## The three icons iOS asks for

Since iOS 18 an app ships three appearances, not one. `AppIcon.appiconset` holds all three at
1024x1024; the light one is also the App Store listing icon.

| Appearance | File | Background | Alpha | What iOS does with it |
|---|---|---|---|---|
| Light (default) | `AppIcon.png` | The full gradient | **Must have none** | Shown as-is, masked to a squircle |
| Dark | `AppIcon-Dark.png` | **None — transparent** | Required | Composited over the system's dark ground |
| Tinted | `AppIcon-Tinted.png` | **None — transparent** | Required | Luminance is mapped onto the user's chosen tint; hue is discarded |

The two rules that cause real rejections and are easy to get backwards:

1. **The light icon must have no alpha channel at all.** App Store Connect rejects a 1024 icon with
   transparency, and it rejects it *after* the build has uploaded and processed, so the mistake
   costs an hour. `make-icon.swift` renders the light variant into a `noneSkipLast` context, which
   cannot carry alpha even by accident.
2. **The dark and tinted icons must keep theirs.** They are the glyph alone. Painting our own dark
   background into the dark variant doubles up with the system's and reads as a sticker sitting on
   the home screen rather than an icon.

Also fixed, and handled by the script: exactly 1024x1024, sRGB, 8 bits per channel, square with
**no rounded corners and no drop shadow of its own** — iOS applies the mask, and a pre-rounded icon
gets its corners clipped twice.

`Contents.json` declares the variants through the `appearances` key. This is the exact shape
`actool` accepts, verified against Xcode 26.2:

```json
{ "appearances": [ { "appearance": "luminosity", "value": "dark" } ],
  "filename": "AppIcon-Dark.png", "idiom": "universal", "platform": "ios", "size": "1024x1024" }
```

A single `1024x1024` `universal` entry is all that is needed. iOS downscales every other size
itself; the old grid of 20pt/29pt/40pt/60pt slots is long gone and adding it back causes warnings.

### Icon Composer

Xcode 26 ships Icon Composer (`/Applications/Xcode.app/Contents/Applications/Icon Composer.app`)
for layered "Liquid Glass" icons with real specular response. It is optional — a 1024 PNG asset
catalog is still fully supported and is what this template uses, because a PNG can be generated
from a script and a `.icon` bundle cannot. Revisit only if an icon needs genuine depth response.

## What the renderer does for detail

`make-icon.swift` draws the glyph into its own transparent layer and then runs a material pass over
it, so **every glyph gets the same depth without any of them being edited**:

- **Rim light.** The solid silhouette minus a copy of itself shifted down leaves the band along the
  top-facing edges. That band is lit, and the matching band at the bottom is shaded. The body of the
  glyph keeps its full brightness — the earlier attempt darkened the whole shape to imply a bevel
  and just made the artwork look dirty.
- **Directional shading.** A lift from the top and a sink from the bottom, clipped to the glyph with
  `.sourceAtop`, plus a specular bloom up and to the left that matches the background highlight.
  When the highlight and the shadow disagree about where the light is, an icon looks wrong without
  the viewer being able to say why.
- **Grain.** Fine luminance noise in soft light. Flat gradients band on an OLED panel and read as
  machine-made; a little texture breaks that up. On the transparent variants the grain is confined
  to the glyph so it does not show as noise in the empty area.
- **Sheen and vignette** on the background only, both deliberately weak — at 60 points on a home
  screen they are felt, not seen.

## House rules for the artwork

1. **At least two distinct elements.** A single shape reads as unfinished at any size. Pair the main
   object with a second that says what the app does with it: a drop beside a syringe, a check badge
   on a capsule, a record card behind a tank. This is the difference between "a crane" and "crane
   inspections".
2. **One glyph per app, checked across the whole portfolio.** Boiler Log and Backflow Log both
   shipped `gauge-board` before anyone noticed. Two apps from one developer wearing the same icon is
   precisely what Apple 4.2.6 looks for. Before choosing, grep every `somexai-*` repo for the glyph
   name, and vary the accent colour too.
3. **Detail has to survive 60 points.** Draw at 1024 but judge at thumbnail size. Three or four
   deliberate features read; a dozen fine ones turn to mush. Interior detail — a lattice, ruled
   lines, graduations, a window — is what separates these from flat-fill clip art, but it needs to
   sit in the largest shapes, not the smallest.
4. **Keep the glyph inside the middle ~80%.** The squircle mask eats the corners, and the home
   screen crops harder than the App Store listing does.
5. **Structural detail belongs inside filled shapes.** Glyph functions use `bg1` for interior detail
   so it reads as a cut-out against the background. Detail drawn in `bg1` *outside* a filled shape
   has nothing behind it in the dark and tinted variants and goes nearly invisible. **Always look at
   all three renders before calling an icon done.**
6. **Check the tinted variant for structure.** Hue is thrown away, so an icon whose elements differ
   only in colour collapses into one silhouette. The glyph, the interior detail and the badge are
   rendered at deliberately separated grey levels (1.0 / 0.30 / 0.56) for this reason.

## Adding a glyph

Glyphs are CoreGraphics paths in `scripts/make-icon.swift`, drawn in a 1024x1024 space with the
origin at the bottom left. Add a `func` and a `case` in the switch at the bottom. Do not use SF
Symbols — Apple's licence forbids them in app icons.

Available helpers: `shadow(_:)` to turn the drop shadow on around a fill, and
`checkBadge(center:radius:)` for the check-in-a-circle that several logging apps share. Use
`glyphColor` for the main shape, `bg1` for interior detail, and `badgeColor` for the one accent
element that carries the app's specific meaning.
