---
name: system-block-diagram
description: Draw schematic-style system block diagrams from electronics design files and project folders. Use when Codex is asked to create, revise, or polish a system block diagram from schematics, DSN/BRD files, IO allocation spreadsheets, BOMs, datasheets, existing block diagram screenshots, or design-material directories; also use for layout cleanup such as routing arrows, labels, crossovers, module spacing, versioned SVG/PNG outputs, and archival iterations.
---

# System Block Diagram

## Overview

Create editable draw.io (`.drawio`) system block diagrams from available electronics design materials, with SVG/PNG preview exports when available. Prioritize correct system relationships, human-editable objects, readable engineering presentation, and versioned iteration.

## Workflow

1. Inventory the current folder first with `rg --files`, then identify schematic exports, IO tables, BOMs, datasheets, screenshots, and prior diagram versions.
2. Read `references/design-rules.md` if it exists. Treat its manual rules as user-maintained drawing preferences that override the defaults below unless they conflict with the user's current request or source facts.
3. Extract the block diagram content from the most reliable source:
   - Prefer explicit IO allocation tables, netlists, BOMs, schematic exports, and datasheet names.
   - Use screenshots only for visual style or sanity checks unless they contain unique system information.
   - Treat unavailable external file paths as context only; do not claim to read them.
4. Identify the central processor/controller, power/clock blocks, high-speed interfaces, sensors, memories, connectivity modules, audio, motors, LEDs, buttons, debug ports, and other peripherals.
5. Generate an editable `.drawio` file as the primary artifact. Use native draw.io shapes/connectors/text for modules, ports, signal lines, and labels; do not embed the diagram as a raster image. Export matching SVG/PNG previews when a browser or image tool is available.
6. Preserve history. For iterative edits, create the next suffix (`_v2`, `_v3`, etc.) instead of overwriting previous versions unless the user explicitly asks.
7. Validate the SVG XML, export the PNG, and visually inspect the result before finishing.

## Diagram Style

- Match schematic-style block diagrams: black background, white border, centered main SoC, yellow peripheral blocks, blue high-speed buses, white control/clock/GPIO lines, cyan PWM/control lines, purple audio lines, red power rails.
- Use English labels for chip/interface names unless the source design uses Chinese labels that must be preserved.
- Include a title, concise source note, and useful legend. Do not add decorative top-right subtitles, right-bottom title tables, or center-bottom explanatory notes unless the user requests them.
- Keep `.drawio` content editable: modules are vertices, routes are edges/connectors, signal names are editable text/edge labels, and decorative icons remain separate editable objects where practical.
- Keep SVG preview text as text, not rasterized paths.
- Do not invent uncertain nets. If the source table marks assignments blank or unreliable, omit them or annotate uncertainty.

## Layout Rules

- Leave enough horizontal room for routing. Increase the SVG `width`/`viewBox` instead of forcing dense wiring through blocks.
- Keep modules aligned in clear columns:
  - left: cameras, sensors, optical/LED/IRCUT functions
  - center: SoC and its port boxes
  - right: memory, connectivity, motor, audio, external connectors
  - top-left: power and clock
- Keep network labels near their corresponding lines, but with visible clearance from all line geometry.
- Maintain spacing between labels and module boxes; if a label is near a module, keep a small margin so it does not look attached to the box.
- Prefer orthogonal routing with short final straight segments before arrowheads.
- Do not place UI-like cards inside cards; groups may use dashed outlines, but functional blocks should remain distinct.

## Routing Rules

- Ensure lines do not pass through functional blocks unless the connection terminates at that block edge.
- Do not use diagonal signal or connector segments. Route all nets with horizontal/vertical orthogonal segments only; replace any slanted line with a right-angle route.
- Arrowheads must not overlap labels, module borders, other lines, or nearby arrowheads.
- Keep arrowheads away from bends. If a line bends into a target, leave a visible straight segment before the arrowhead.
- Avoid placing arrowheads immediately adjacent to unrelated lines; shift the bend or target approach when necessary.
- When unrelated nets cross, add a small bridge/jump on one net at the crossing point to indicate no electrical connection. Use this especially where a vertical segment crosses a horizontal segment from a different net.
- Do not use bridge/jump marks for real connections. Real connection points should terminate at a block or be intentionally shown as joined.
- When two similar nets run in parallel, separate their vertical trunks or stagger their labels so they cannot be mistaken as one net.

## Label Rules

- Keep network names close to their associated line, generally 6-12 px away when space allows.
- Check labels against the full polyline, not only the nearest horizontal segment. Avoid overlaps with vertical bends, bridge arcs, arrowheads, dashed group borders, and module outlines.
- If nearby nets make close placement ambiguous, move the label to the nearest clear side and add or keep an explanatory note such as: "信号名按最近同色线对应".
- For long right-side labels, align them so the text ends before the arrowhead and leaves a visible gap.
- Use a thin black stroke behind white/blue/red labels on black backgrounds to preserve readability and create a small visual clearance from crossing lines.

## Draw.io Empty Diagram Prevention

- Generate valid draw.io XML, not just generic XML. Required structure:
  - `<mxfile>`
  - `<diagram>`
  - `<mxGraphModel>`
  - `<root>`
  - `<mxCell id="0"/>`
  - `<mxCell id="1" parent="0"/>`
- Attach every visible object to `parent="1"` or to a valid visible group parent.
- Ensure the file is not an empty shell. A usable block diagram must contain multiple visible `vertex="1"` cells and multiple `edge="1"` connector cells.
- Do not create the output file before the graph content is ready unless the write is atomic. Avoid leaving a zero-byte, half-written, or outer-wrapper-only `.drawio` file after a generation failure.
- Keep object coordinates within the draw.io page bounds. If `pageWidth`/`pageHeight` are set, verify major modules have non-negative coordinates and fit within the visible page.
- Avoid compressed `<diagram>` payloads unless the deflate/base64/urlencode pipeline is tested. Prefer uncompressed `<mxGraphModel>` XML because it is easier to inspect and repair.
- When validating uncompressed `.drawio` files, inspect `<mxGraphModel>` as a child/descendant of `<diagram>` instead of assuming all diagram content is stored in `diagram.text`. Otherwise a valid editable diagram can be falsely reported as having zero cells.
- Do not use a single embedded image as the primary diagram. If a preview image is included, it must not replace editable module and connector cells.
- Ensure visible styles are actually visible on the chosen background. Avoid zero width/height objects and combinations such as `fillColor=none;strokeColor=none` for required objects.
- Common causes of apparently empty draw.io files are missing root cells, cells without a valid parent, all shapes placed outside the page, failed compressed payload encoding, image references that cannot load, invisible styles, or generation scripts that left only an XML wrapper after an error.

## Versioning And Output

- Name the first generated diagram with a descriptive project prefix, for example `系统框图/<project>_系统框图.drawio`.
- For revisions, append `_v2`, `_v3`, etc. Do not overwrite unless requested.
- Export matching SVG/PNG preview names beside the `.drawio` file when tools are available.
- Optionally keep a structured JSON source beside the diagram when it helps regenerate or revise the `.drawio` deterministically.
- When using Chrome/Edge headless on Windows paths, encode PowerShell commands if Chinese paths or spaces make quoting unreliable.
- If export tools are unavailable, still provide the `.drawio` file and state which preview exports were not possible.

## Validation Checklist

Before final response:

- Parse the `.drawio` XML successfully and confirm it contains editable `mxCell` vertices and edges rather than a single embedded image.
- Confirm the `.drawio` has `mxGraphModel/root`, `mxCell id="0"`, and `mxCell id="1" parent="0"`.
- For uncompressed `.drawio`, count cells from `.//mxGraphModel`; for compressed payloads, decode first and only then count cells.
- Count visible objects. Require `vertex` count > 0 and `edge` count > 0 for any non-trivial system block diagram; report the counts when validating a new draw.io output.
- Confirm major object coordinates are inside the page bounds and required objects have non-zero width/height.
- Confirm the file size is plausible for the diagram and is not zero-byte or outer-wrapper-only.
- Export SVG/PNG previews at the intended canvas size when tools are available.
- Visually inspect the preview for:
  - no line-through-block artifacts
  - no label overlap with horizontal or vertical wire segments
  - no label overlap with arrowheads
  - no arrowhead overlap with unrelated lines
  - bridge/jump marks at unrelated crossings
  - adequate spacing between network names and module boxes
  - title block/version matching the output suffix
- Report the exact new `.drawio` path plus any SVG/PNG preview paths and mention the canvas size.
