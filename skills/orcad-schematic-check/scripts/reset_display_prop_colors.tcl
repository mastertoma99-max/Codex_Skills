# Reset display-property text colors on schematic component instances.
# Usage:
#   tclsh.exe reset_display_prop_colors.tcl <design.dsn> report|apply <logfile>

if {[llength $argv] < 1} {
    puts "Usage: reset_display_prop_colors.tcl <design.dsn> report|apply <logfile>"
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

set g_logPath reset_display_prop_colors.log
if {[llength $argv] >= 3} {
    set g_logPath [lindex $argv 2]
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
set g_totalDisplayProps 0
set g_nonDefaultProps 0
set g_alreadyDefaultProps 0
set g_setProps 0
set g_failedProps 0

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

proc getDisplayPropName {dispProp} {
    set name [DboTclHelper_sMakeCString]
    if {[catch {$dispProp GetName $name}]} {
        return ""
    }
    return [cstrValue $name]
}

proc resetDisplayPropsOnInst {partInst pageLabel} {
    global g_mode g_totalDisplayProps g_nonDefaultProps g_alreadyDefaultProps
    global g_setProps g_failedProps

    set status [DboState]
    set iter [$partInst NewDisplayPropsIter $status]
    set dispProp [$iter NextProp $status]
    set partName [getObjectName $partInst]

    while {![string equal $dispProp NULL]} {
        incr g_totalDisplayProps

        set propName [getDisplayPropName $dispProp]
        set oldColor UNKNOWN
        if {![catch {set oldColor [$dispProp GetColor $status]}]} {
            if {[string equal $oldColor $::DboValue_DEFAULT_OBJECT_COLOR]} {
                incr g_alreadyDefaultProps
            } else {
                incr g_nonDefaultProps
                logLine "CANDIDATE\t$pageLabel\t$partName\t$propName\toldColor=$oldColor"
                if {[string equal $g_mode apply]} {
                    set setStatus [$dispProp SetColor $::DboValue_DEFAULT_OBJECT_COLOR]
                    if {[$setStatus Succeeded]} {
                        incr g_setProps
                        logLine "SET\t$pageLabel\t$partName\t$propName\toldColor=$oldColor\tnewColor=$::DboValue_DEFAULT_OBJECT_COLOR"
                    } else {
                        incr g_failedProps
                        logLine "FAILED\t$pageLabel\t$partName\t$propName\toldColor=$oldColor"
                    }
                }
            }
        } else {
            incr g_failedProps
            logLine "FAILED_GET_COLOR\t$pageLabel\t$partName\t$propName"
        }

        set dispProp [$iter NextProp $status]
    }

    catch {delete_DboDisplayPropsIter $iter}
    $status -delete
}

proc visitPageInsts {pageObj schematicName} {
    global g_totalParts

    set status [DboState]
    set pageName [getObjectName $pageObj]
    if {[string equal $schematicName ""]} {
        set pageLabel $pageName
    } else {
        set pageLabel "$schematicName/$pageName"
    }

    set partIter [$pageObj NewPartInstsIter $status]
    set partInst [$partIter NextPartInst $status]
    while {![string equal $partInst NULL]} {
        incr g_totalParts
        resetDisplayPropsOnInst $partInst $pageLabel
        set partInst [$partIter NextPartInst $status]
    }

    catch {delete_DboPagePartInstsIter $partIter}
    $status -delete
}

proc visitPages {schematicObj schematicName} {
    set status [DboState]
    set pagesIter [$schematicObj NewPagesIter $status]
    set pageObj [$pagesIter NextPage $status]
    while {![string equal $pageObj NULL]} {
        visitPageInsts $pageObj $schematicName
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
logLine "defaultColor=$::DboValue_DEFAULT_OBJECT_COLOR"

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

set saveOk 1
if {[string equal $g_mode apply] && $g_nonDefaultProps > 0} {
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
logLine "displayProps=$g_totalDisplayProps"
logLine "nonDefault=$g_nonDefaultProps"
logLine "alreadyDefault=$g_alreadyDefaultProps"
logLine "set=$g_setProps"
logLine "failed=$g_failedProps"
close $g_log

puts "parts=$g_totalParts displayProps=$g_totalDisplayProps nonDefault=$g_nonDefaultProps alreadyDefault=$g_alreadyDefaultProps set=$g_setProps failed=$g_failedProps"
if {$saveOk == 0} {
    exit 30
}
exit 0
