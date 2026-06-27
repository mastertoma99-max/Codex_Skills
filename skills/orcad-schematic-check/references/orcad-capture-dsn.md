# OrCAD/Capture DSN Maintenance Notes

## Environment Pattern

- Use Cadence SPB 17.4 for designs saved by Capture/Capture CIS 17.4.
- Tcl shell used successfully:
  - `D:/3_Software/Cadence/SPB_17.4/tools/bin/tclsh.exe`
- DB API DLL:
  - `D:/3_Software/Cadence/SPB_17.4/tools/bin/orDb_Dll_Tcl64.dll`
- Load with:
  ```tcl
  load "$g_toolsRoot/bin/orDb_Dll_Tcl64.dll" DboTclWriteBasic
  ```

## Traversal Pattern

Open and traverse schematics with:

```tcl
set session [DboTclHelper_sCreateSession]
set status [DboState]
set designPathC [DboTclHelper_sMakeCString $g_designPath]
set design [DboSession_GetDesignAndSchematics $session $designPathC $status]

set schematicIter [$design NewViewsIter $status $::IterDefs_SCHEMATICS]
set viewObj [$schematicIter NextView $status]
set schematicObj [DboViewToDboSchematic $viewObj]
set pagesIter [$schematicObj NewPagesIter $status]
set pageObj [$pagesIter NextPage $status]
set partIter [$pageObj NewPartInstsIter $status]
set partInst [$partIter NextPartInst $status]
```

Save with:

```tcl
DboSession_MarkAllLibForSave $session $design
set saveStatus [DboSession_SaveDesign $session $design]
```

Then remove design, delete the session, and release created pointers.

## Display Property Color Reset

The tested flow:

1. Traverse each part instance.
2. Iterate display props with `$partInst NewDisplayPropsIter`.
3. Read color with `$dispProp GetColor $status`.
4. If color differs from `$::DboValue_DEFAULT_OBJECT_COLOR`, call:
   ```tcl
   $dispProp SetColor $::DboValue_DEFAULT_OBJECT_COLOR
   ```
5. Save and reopen.

Observed default color value was `48`, but scripts should use the symbolic constant.

Tested result on `CBX62_C01_V1_06251932_test.DSN`:

- Before apply: `parts=69 displayProps=210 nonDefault=17 alreadyDefault=193`
- Apply: `set=17 failed=0`
- Verify after reopen: `nonDefault=0`

## Reference Renumbering

Page numbers are parsed from leading digits in page names:

- `05_POWER_Manage` -> `5`
- `10_FIX_HOLE` -> `10`

Reference parsing:

```tcl
regexp {^([^0-9]+)([0-9]+)([A-Za-z]*)$} $refName -> prefix number suffix
```

Reference policies:

- `all`: sort by page, prefix, Y, X; assign from `pageNumber * 100`.
- `nonconforming`: keep existing references whose numeric portion is already within the page range, then fill unused numbers for nonconforming references.

Use a two-phase write:

1. Assign unique temporary references like `TMPREN00001`.
2. Assign final references.

This avoids temporary collisions for swaps such as `TP500` and `TP501`.

## Reference Save Pitfall

`$placedInst SetReference` returned success but did not persist the `Reference` values read by `$partInst GetReference`.

The working approach:

```tcl
set st [$partInst SetReference $refC]
if {[$st OK] && [string equal [getReference $partInst] $newRef]} {
    $partInst SetOccsModified 1
    $partInst MarkModified
}
```

Without `SetOccsModified` and `MarkModified`, the in-session value may change but `SaveDesign` may leave the DSN file unchanged.

Tested result on `CBX62_C01_V1_06251932_test.DSN`:

- Report before apply with full resort: `parts=69 planned=69 changes=65 skipped=0 duplicateExisting=0 duplicateTargets=0`
- Apply: `tempSet=65 set=65 failed=0`
- Verify after reopen: `changes=0`

Policy correction test:

- Already-renumbered DSN with default `nonconforming`: `changes=0`
- Pre-renumber backup with `all`: `changes=65`
- Pre-renumber backup with `nonconforming`: `changes=56`

## Safety Checklist

- Never patch `.DSN` binary content directly.
- Never apply before producing a report log.
- Stop on duplicate targets.
- Stop on skipped references unless the user explicitly accepts them.
- Keep backups adjacent to the DSN unless the user requests another location.
- Preserve user changes and unrelated files.
