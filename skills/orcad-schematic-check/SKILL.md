---
name: orcad-schematic-check
description: Inspect and safely batch-maintain OrCAD/Capture schematic DSN files. Use when working with `.DSN` schematics that need report-first checks, component display property color reset, reference designator renumbering by page, or other Cadence Tcl DB API edits where backups, logs, and reopen verification matter.
---

# OrCAD Schematic Check

## Core Rules

- Treat `.DSN` files as OrCAD/Capture binary design databases, not text files.
- Prefer Cadence 17.4 Tcl DB API for 17.4 designs. Do not save a newer DSN with older Cadence tools.
- Use Windows paths with forward slashes when launching Cadence tools from WSL, such as `D:/...`.
- Always run `report` before `apply`.
- Always create a backup before writing.
- Always verify by reopening the DSN in a fresh process after `apply`.
- Record commands, counts, logs, and pitfalls in the task notes if the user is building a reusable skill.

## Available Scripts

The skill bundles deterministic Tcl scripts in `scripts/`.

- `scripts/reset_display_prop_colors.tcl`
  - Resets component instance display property colors, including visible `Reference`, `Value`, and footprint-like display props, to `DboValue_DEFAULT_OBJECT_COLOR`.
  - Usage:
    ```bash
    cmd.exe /C D:/3_Software/Cadence/SPB_17.4/tools/bin/tclsh.exe D:/path/to/reset_display_prop_colors.tcl D:/path/to/design.DSN report D:/path/to/report.log
    cmd.exe /C D:/3_Software/Cadence/SPB_17.4/tools/bin/tclsh.exe D:/path/to/reset_display_prop_colors.tcl D:/path/to/design.DSN apply D:/path/to/apply.log
    ```

- `scripts/renumber_references_by_page.tcl`
  - Renumbers part `Reference` values using the leading number in the page name.
  - Usage:
    ```bash
    cmd.exe /C D:/3_Software/Cadence/SPB_17.4/tools/bin/tclsh.exe D:/path/to/renumber_references_by_page.tcl D:/path/to/design.DSN report D:/path/to/report.log nonconforming
    cmd.exe /C D:/3_Software/Cadence/SPB_17.4/tools/bin/tclsh.exe D:/path/to/renumber_references_by_page.tcl D:/path/to/design.DSN apply D:/path/to/apply.log nonconforming
    ```

## Reference Renumber Policy

Before applying reference renumbering, ask the user which policy to use:

- `nonconforming`: keep references whose numeric portion already matches the current page range, and only assign new numbers to nonconforming references. This is the default and safest policy.
- `all`: fully resort and renumber every component in each page/prefix group.

For page `N`, a reference is conforming when its numeric portion is in `[N*100, N*100+99]`. For example, on page 5, `R500` through `R599` are conforming.

In `nonconforming` mode:

- Reserve all already-conforming references first.
- Assign nonconforming references to the first available numbers in the page/prefix range.
- Do not reorder already-conforming references just because schematic coordinates differ.

In `all` mode:

- Sort part instances by page, prefix, Y coordinate, then X coordinate.
- Assign references from `pageNumber * 100`, incrementing independently per prefix.

## Write Workflow

1. Identify the DSN and Cadence version.
2. Convert WSL paths to forward-slash Windows paths for Cadence commands.
3. Run the script in `report` mode.
4. Inspect summary counts:
   - For color reset: `nonDefault`, `set`, `failed`.
   - For renumbering: `changes`, `skipped`, `duplicateExisting`, `duplicateTargets`, `failed`.
5. If any target reference duplicates or skipped entries need review, stop and explain.
6. Create a timestamped or task-specific backup.
7. Run `apply`.
8. Run `report` again in a fresh process against the saved DSN.
9. Confirm the verification target:
   - Color reset: `nonDefault=0`.
   - Renumbering: `changes=0`.

## Cadence Tcl Pitfalls

- `$placedInst SetReference` can return success but not persist the value read by `$partInst GetReference`.
- `$partInst SetReference` can update the value in session but not make the design save unless the part instance is marked modified.
- After successfully setting a part reference, call:
  ```tcl
  $partInst SetOccsModified 1
  $partInst MarkModified
  ```
- Use temporary references during batch renumbering to avoid mid-apply collisions when two existing references swap values.
- Use `DboSession_MarkAllLibForSave` and `DboSession_SaveDesign`, then close and reopen for verification.

## Extra Detail

Read `references/orcad-capture-dsn.md` when adapting scripts, changing Cadence versions, or troubleshooting save/verification mismatches.
