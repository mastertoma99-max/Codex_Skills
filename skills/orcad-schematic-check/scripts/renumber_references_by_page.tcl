# Renumber OrCAD/Capture schematic part references by page number.
# Usage:
#   tclsh.exe renumber_references_by_page.tcl <design.dsn> report|apply <logfile> [all|nonconforming]

if {[llength $argv] < 1} {
    puts "Usage: renumber_references_by_page.tcl <design.dsn> report|apply <logfile> [all|nonconforming]"
    exit 2
}

set g_designPath [lindex $argv 0]
set g_mode report
if {[llength $argv] >= 2} {
    set g_mode [string tolower [lindex $argv 1]]
}
if {![string equal $g_mode report] && ![string equal $g_mode apply]} {
    puts "Mode must be report or apply"
    exit 2
}

set g_logPath renumber_references_by_page.log
if {[llength $argv] >= 3} {
    set g_logPath [lindex $argv 2]
}

set g_policy nonconforming
if {[llength $argv] >= 4} {
    set g_policy [string tolower [lindex $argv 3]]
}
if {![string equal $g_policy all] && ![string equal $g_policy nonconforming]} {
    puts "Policy must be all or nonconforming"
    exit 2
}

set g_spbRoot "D:/3_Software/Cadence/SPB_17.4"
set g_toolsRoot "$g_spbRoot/tools"
if {[info exists ::env(PATH)]} {
    set ::env(PATH) "$g_spbRoot/bin;$g_spbRoot/wbin;$g_spbRoot/tcltk/bin;$g_toolsRoot/bin;$g_toolsRoot/capture;$::env(PATH)"
} else {
    set ::env(PATH) "$g_spbRoot/bin;$g_spbRoot/wbin;$g_spbRoot/tcltk/bin;$g_toolsRoot/bin;$g_toolsRoot/capture"
}

if {[catch {load "$g_toolsRoot/bin/orDb_Dll_Tcl64.dll" DboTclWriteBasic} g_loadErr]} {
    puts "ERROR: failed to load OrCAD Tcl DB API: $g_loadErr"
    exit 10
}

set g_log [open $g_logPath w]
set g_totalParts 0
set g_planCount 0
set g_changeCount 0
set g_skipCount 0
set g_existingDuplicateCount 0
set g_duplicateCount 0
set g_tempSetCount 0
set g_setCount 0
set g_failedCount 0
set g_entries {}
array set g_existingRefs {}
array set g_newRefs {}

proc logLine {msg} {
    global g_log
    puts $g_log $msg
}

proc cstrValue {cstr} {
    set value [DboTclHelper_sGetConstCharPtr $cstr]
    if {[string equal $value NULL]} {
        return ""
    }
    return $value
}

proc getObjectName {obj} {
    set name [DboTclHelper_sMakeCString]
    if {[catch {$obj GetName $name}]} {
        return ""
    }
    return [cstrValue $name]
}

proc getReference {partInst} {
    set ref [DboTclHelper_sMakeCString]
    if {[catch {$partInst GetReference $ref}]} {
        return ""
    }
    return [cstrValue $ref]
}

proc parsePageNumber {pageName fallbackIndex} {
    if {[regexp {^0*([0-9]+)} $pageName -> pageNum]} {
        return [expr {$pageNum + 0}]
    }
    return $fallbackIndex
}

proc parseRefPrefix {refName} {
    if {[regexp {^([^0-9]+)([0-9]+)([A-Za-z]*)$} $refName -> prefix number suffix]} {
        return [list 1 $prefix $number $suffix]
    }
    return [list 0 "" "" ""]
}

proc getInstPosition {partInst} {
    set status [DboState]
    set x 0
    set y 0
    set source "none"

    if {![catch {set loc [$partInst GetLocation $status]}] && ![string equal $loc NULL]} {
        if {![catch {set x [DboTclHelper_sGetCPointX $loc]}] && ![catch {set y [DboTclHelper_sGetCPointY $loc]}]} {
            set source "location"
            $status -delete
            return [list $x $y $source]
        }
    }

    if {![catch {set bbox [$partInst GetBoundingBox]}] && ![string equal $bbox NULL]} {
        if {![catch {set topLeft [DboTclHelper_sGetCRectTopLeft $bbox]}] && ![string equal $topLeft NULL]} {
            if {![catch {set x [DboTclHelper_sGetCPointX $topLeft]}] && ![catch {set y [DboTclHelper_sGetCPointY $topLeft]}]} {
                set source "bbox"
            }
        }
    }

    $status -delete
    return [list $x $y $source]
}

proc markReferenceModified {partInst} {
    catch {$partInst SetOccsModified 1}
    catch {$partInst MarkModified}
}

proc addEntry {partInst schematicName pageName pageNum pageIndex instIndex} {
    global g_entries g_totalParts g_skipCount g_existingRefs

    incr g_totalParts
    set refName [getReference $partInst]
    if {[string equal $refName ""]} {
        incr g_skipCount
        logLine "SKIP\t$pageName\tblank-reference"
        return
    }

    set parsed [parseRefPrefix $refName]
    if {[lindex $parsed 0] == 0} {
        incr g_skipCount
        logLine "SKIP\t$pageName\t$refName\tunparseable-reference"
        return
    }

    set prefix [lindex $parsed 1]
    set suffix [lindex $parsed 3]
    set pos [getInstPosition $partInst]
    set x [lindex $pos 0]
    set y [lindex $pos 1]
    set posSource [lindex $pos 2]
    set pageLabel "$schematicName/$pageName"

    incr g_existingRefs($refName)
    lappend g_entries [list $pageIndex $pageNum $pageName $pageLabel $prefix $suffix $x $y $instIndex $refName $partInst $posSource]
}

proc entryCompare {a b} {
    foreach idx {0 4 7 6 8 9} numeric {1 0 1 1 1 0} {
        set av [lindex $a $idx]
        set bv [lindex $b $idx]
        if {$numeric} {
            if {$av < $bv} { return -1 }
            if {$av > $bv} { return 1 }
        } else {
            set cmp [string compare $av $bv]
            if {$cmp != 0} { return $cmp }
        }
    }
    return 0
}

proc buildPlan {} {
    global g_entries g_policy g_planCount g_changeCount g_existingDuplicateCount g_duplicateCount g_existingRefs g_newRefs

    set sorted [lsort -command entryCompare $g_entries]
    set planned {}

    if {[string equal $g_policy all]} {
        array set counters {}

        foreach entry $sorted {
            set pageNum [lindex $entry 1]
            set prefix [lindex $entry 4]
            set suffix [lindex $entry 5]
            set oldRef [lindex $entry 9]
            set key "$pageNum|$prefix"
            if {![info exists counters($key)]} {
                set counters($key) [expr {$pageNum * 100}]
            } else {
                incr counters($key)
            }
            set newRef "$prefix$counters($key)$suffix"
            incr g_newRefs($newRef)
            incr g_planCount
            if {![string equal $oldRef $newRef]} {
                incr g_changeCount
            }
            lappend planned [linsert $entry end $newRef]
        }
    } else {
        array set targetRefs {}
        set deferred {}

        foreach entry $sorted {
            set pageNum [lindex $entry 1]
            set prefix [lindex $entry 4]
            set oldRef [lindex $entry 9]
            set parsed [parseRefPrefix $oldRef]
            set oldNumber [expr {[lindex $parsed 2] + 0}]
            set base [expr {$pageNum * 100}]
            set limit [expr {$base + 100}]

            if {$oldNumber >= $base && $oldNumber < $limit && ![info exists targetRefs($oldRef)]} {
                set targetRefs($oldRef) 1
                incr g_newRefs($oldRef)
                incr g_planCount
                lappend planned [linsert $entry end $oldRef]
            } else {
                lappend deferred $entry
            }
        }

        array set counters {}
        foreach entry $deferred {
            set pageNum [lindex $entry 1]
            set prefix [lindex $entry 4]
            set suffix [lindex $entry 5]
            set oldRef [lindex $entry 9]
            set key "$pageNum|$prefix"
            if {![info exists counters($key)]} {
                set counters($key) [expr {$pageNum * 100}]
            }

            while {1} {
                set newRef "$prefix$counters($key)$suffix"
                incr counters($key)
                if {![info exists targetRefs($newRef)]} {
                    set targetRefs($newRef) 1
                    break
                }
            }

            incr g_newRefs($newRef)
            incr g_planCount
            if {![string equal $oldRef $newRef]} {
                incr g_changeCount
            }
            lappend planned [linsert $entry end $newRef]
        }
    }

    foreach refName [array names g_newRefs] {
        if {$g_newRefs($refName) > 1} {
            incr g_duplicateCount
            logLine "DUPLICATE_TARGET\tref=$refName\tcount=$g_newRefs($refName)"
        }
    }

    foreach refName [array names g_existingRefs] {
        if {$g_existingRefs($refName) > 1} {
            incr g_existingDuplicateCount
            logLine "DUPLICATE_EXISTING\tref=$refName\tcount=$g_existingRefs($refName)"
        }
    }

    return $planned
}

proc setReference {partInst newRef} {
    set refC [DboTclHelper_sMakeCString $newRef]

    if {![catch {set st [$partInst SetReference $refC]}] && [$st OK] && [string equal [getReference $partInst] $newRef]} {
        markReferenceModified $partInst
        return [list 1 "part"]
    }

    if {![catch {set st [DboPartInst_sSetReference $partInst $refC]}] && [$st OK] && [string equal [getReference $partInst] $newRef]} {
        markReferenceModified $partInst
        return [list 1 "part-static"]
    }

    if {![catch {set drawn [DboPartInstToDboDrawnInst $partInst]}] && ![string equal $drawn NULL]} {
        if {![catch {set st [$drawn SetReference $refC 1]}] && [$st OK] && [string equal [getReference $partInst] $newRef]} {
            markReferenceModified $partInst
            return [list 1 "drawn"]
        }
    }

    if {![catch {set st [DboPlacedInst_sSetReferenceDesignator $partInst $refC]}] && [$st OK] && [string equal [getReference $partInst] $newRef]} {
        markReferenceModified $partInst
        return [list 1 "placed-refdes-static"]
    }

    if {![catch {set st [DboInstOccurrence_sSetReference $partInst $refC]}] && [$st OK] && [string equal [getReference $partInst] $newRef]} {
        markReferenceModified $partInst
        return [list 1 "occurrence-static"]
    }

    if {![catch {set placed [DboPartInstToDboPlacedInst $partInst]}] && ![string equal $placed NULL]} {
        if {![catch {set st [$placed SetReference $refC]}] && [$st OK] && [string equal [getReference $partInst] $newRef]} {
            markReferenceModified $partInst
            return [list 1 "placed"]
        }
    }

    return [list 0 "unsupported"]
}

proc emitAndMaybeApplyPlan {planned} {
    global g_mode g_tempSetCount g_setCount g_failedCount g_duplicateCount

    if {[string equal $g_mode apply] && $g_duplicateCount > 0} {
        logLine "ERROR: duplicate target references detected; apply aborted before edits"
        return
    }

    set changed {}
    foreach entry $planned {
        set pageNum [lindex $entry 1]
        set pageName [lindex $entry 2]
        set pageLabel [lindex $entry 3]
        set prefix [lindex $entry 4]
        set x [lindex $entry 6]
        set y [lindex $entry 7]
        set oldRef [lindex $entry 9]
        set partInst [lindex $entry 10]
        set posSource [lindex $entry 11]
        set newRef [lindex $entry 12]
        set action "KEEP"
        if {![string equal $oldRef $newRef]} {
            set action "CHANGE"
        }

        logLine "PLAN\t$action\tpage=$pageNum\tpageName=$pageName\tprefix=$prefix\told=$oldRef\tnew=$newRef\tx=$x\ty=$y\tpos=$posSource\tlabel=$pageLabel"

        if {![string equal $oldRef $newRef]} {
            lappend changed $entry
        }
    }

    if {![string equal $g_mode apply]} {
        return
    }

    set tempIndex 0
    set tempPlan {}
    foreach entry $changed {
        incr tempIndex
        set oldRef [lindex $entry 9]
        set partInst [lindex $entry 10]
        set tempRef [format "TMPREN%05d" $tempIndex]
        set result [setReference $partInst $tempRef]
        if {[lindex $result 0] == 1} {
            incr g_tempSetCount
            logLine "TEMP_SET\told=$oldRef\ttemp=$tempRef\tmethod=[lindex $result 1]"
            lappend tempPlan [linsert $entry end $tempRef]
        } else {
            incr g_failedCount
            logLine "FAILED_TEMP\told=$oldRef\ttemp=$tempRef\treason=[lindex $result 1]"
        }
    }

    if {$g_failedCount > 0} {
        logLine "ERROR: final reference apply aborted because temporary phase failed"
        return
    }

    foreach entry $tempPlan {
        set oldRef [lindex $entry 9]
        set partInst [lindex $entry 10]
        set newRef [lindex $entry 12]
        set tempRef [lindex $entry 13]
        set result [setReference $partInst $newRef]
        if {[lindex $result 0] == 1} {
            incr g_setCount
            logLine "SET\told=$oldRef\ttemp=$tempRef\tnew=$newRef\tmethod=[lindex $result 1]"
        } else {
            incr g_failedCount
            logLine "FAILED\told=$oldRef\ttemp=$tempRef\tnew=$newRef\treason=[lindex $result 1]"
        }
    }
}

proc visitPageInsts {pageObj schematicName pageIndex} {
    set pageName [getObjectName $pageObj]
    set pageNum [parsePageNumber $pageName $pageIndex]
    set status [DboState]
    set instIndex 0

    logLine "PAGE\tindex=$pageIndex\tnumber=$pageNum\tname=$pageName\tschematic=$schematicName"

    set partIter [$pageObj NewPartInstsIter $status]
    set partInst [$partIter NextPartInst $status]
    while {![string equal $partInst NULL]} {
        incr instIndex
        addEntry $partInst $schematicName $pageName $pageNum $pageIndex $instIndex
        set partInst [$partIter NextPartInst $status]
    }

    catch {delete_DboPagePartInstsIter $partIter}
    $status -delete
}

proc visitPages {schematicObj schematicName} {
    set status [DboState]
    set pageIndex 0
    set pagesIter [$schematicObj NewPagesIter $status]
    set pageObj [$pagesIter NextPage $status]
    while {![string equal $pageObj NULL]} {
        incr pageIndex
        visitPageInsts $pageObj $schematicName $pageIndex
        set pageObj [$pagesIter NextPage $status]
    }
    catch {delete_DboSchematicPagesIter $pagesIter}
    $status -delete
}

proc visitSchematics {designObj} {
    set status [DboState]
    set schematicIter [$designObj NewViewsIter $status $::IterDefs_SCHEMATICS]
    set viewObj [$schematicIter NextView $status]
    while {![string equal $viewObj NULL]} {
        set schematicObj [DboViewToDboSchematic $viewObj]
        if {![string equal $schematicObj NULL]} {
            visitPages $schematicObj [getObjectName $schematicObj]
        }
        set viewObj [$schematicIter NextView $status]
    }
    catch {delete_DboLibViewsIter $schematicIter}
    $status -delete
}

logLine "design=$g_designPath"
logLine "mode=$g_mode"
logLine "policy=$g_policy"
logLine "rule=prefix + pageNumber*100 + per-page-per-prefix-index"
logLine "sort=page, prefix, y, x"

set session [DboTclHelper_sCreateSession]
set status [DboState]
set designPathC [DboTclHelper_sMakeCString $g_designPath]
set design [DboSession_GetDesignAndSchematics $session $designPathC $status]

if {[string equal $design NULL]} {
    logLine "ERROR: unable to open design"
    close $g_log
    puts "ERROR: unable to open design: $g_designPath"
    exit 20
}

visitSchematics $design
set planned [buildPlan]
emitAndMaybeApplyPlan $planned

set saveOk 1
if {[string equal $g_mode apply] && $g_failedCount == 0 && $g_duplicateCount == 0 && $g_setCount > 0} {
    DboSession_MarkAllLibForSave $session $design
    set saveStatus [DboSession_SaveDesign $session $design]
    if {[DboState_Failed $saveStatus] == 1} {
        set saveOk 0
        logLine "ERROR: save failed"
    } else {
        logLine "SAVE: ok"
    }
}

DboSession_RemoveDesign $session $design
delete_DboSession $session
$status -delete
DboTclHelper_sReleaseAllCreatedPtrs

logLine "parts=$g_totalParts"
logLine "planned=$g_planCount"
logLine "changes=$g_changeCount"
logLine "skipped=$g_skipCount"
logLine "duplicateExisting=$g_existingDuplicateCount"
logLine "duplicateTargets=$g_duplicateCount"
logLine "tempSet=$g_tempSetCount"
logLine "set=$g_setCount"
logLine "failed=$g_failedCount"
close $g_log

puts "parts=$g_totalParts planned=$g_planCount changes=$g_changeCount skipped=$g_skipCount duplicateExisting=$g_existingDuplicateCount duplicateTargets=$g_duplicateCount tempSet=$g_tempSetCount set=$g_setCount failed=$g_failedCount"
if {$saveOk == 0 || $g_failedCount > 0 || $g_duplicateCount > 0} {
    exit 30
}
exit 0
