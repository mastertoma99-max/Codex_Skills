# System Block Diagram Design Rules

These rules are user-maintained. Add project or personal drawing preferences here before using `$system-block-diagram`; the skill should read this file and apply these rules unless the current user request says otherwise.

## Current Preferences

- Preserve every iteration. Create the next version suffix instead of overwriting existing SVG/PNG files.
- Use a black schematic-style canvas with white frame, centered SoC, yellow functional blocks, blue high-speed buses, white control/clock/GPIO lines, cyan PWM/control lines, purple audio, and red power.
- Keep the main title and source note. Do not add a decorative right-top `Block Diagram` subtitle.
- Keep the left-bottom legend when it helps readability.
- Do not add a right-bottom project/title/revision table unless specifically requested.
- Do not add center-bottom explanatory small text unless specifically requested.
- Put network names close to their corresponding lines, but keep visible clearance from horizontal segments, vertical bends, arrowheads, module borders, dashed group borders, and bridge arcs.
- Keep network names slightly away from module boxes so they do not look attached to a module.
- If a label must move farther away because of nearby wires, keep it on the nearest clear side and make correspondence clear.
- Ensure arrows do not touch labels, module borders, unrelated lines, or other arrowheads.
- Keep arrowheads away from bends; leave a short straight segment before the arrowhead.
- Route lines orthogonally and avoid passing through functional blocks.
- When unrelated nets cross, add a compact semi-circular bridge on one net to show no electrical connection.
- Keep bridge arcs compact. The current preferred bridge size is about 18 px outward with about 18 px vertical span.
- Separate parallel trunks and stagger labels for similar nets so they cannot be mistaken as one net.
- Increase canvas width when the left or right side becomes crowded instead of forcing dense routes through blocks.

## Manual Additions

Add new rules below this line. Keep each rule as a short bullet so future updates are easy to scan.
