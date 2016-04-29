package require wcb

proc isIdxReadonly {win idx} {
    return [expr (([lsearch [$win tag names $idx] readonly] >= 0) && \
        ([lsearch [$win tag names $idx-1c] readonly] >= 0)) || [$win compare $idx >= end-1c]]
}

# Modifies insertion cursor so it is always on editable text
# This is a callback function that gets called every time the 
# insertion cursor gets moved.  The idx arg tells where the
# cursor is about to be moved to.
proc getNearestWritableIdx {win idx} {
    set retIdx $idx
    
    # Is the cursor about to be moved to a region that isn't writable?
    if {[isIdxReadonly $win $idx]} {
        set readonlyRange [$win tag prevrange readonly $idx]
        if {[llength $readonlyRange] == 0} {
            set readonlyRange [$win tag nextrange readonly $idx]
            if {[llength $readonlyRange] == 0} {
                return $retIdx
            }
        } 
        set leftDestIdx [lindex $readonlyRange 0]
        set rightDestIdx [lindex $readonlyRange 1]
        set separatorRange [$win tag prevrange separator $idx]
        if {[llength $separatorRange] > 0} {
            set leftSepIdx [lindex $separatorRange 0]
            if {[$win compare $leftSepIdx > $leftDestIdx]} {
                set leftDestIdx $leftSepIdx
            }
        }
        set separatorRange [$win tag nextrange separator $idx]
        if {[llength $separatorRange] > 0} {
            set rightSepIdx [lindex $separatorRange 0]
            if {[$win compare $rightSepIdx < $rightDestIdx]} {
                set rightDestIdx $rightSepIdx
            }
        }
        
        # Is the destination index at the very start of the widget?
        if {[$win compare $leftDestIdx == 1.0]} {
            # Yes.  Move to the start of the first writeable region
            set retIdx $rightDestIdx

        # No.  Is the destination index at the very end of the widget?
        } elseif {[$win compare $rightDestIdx == end-1c]} {
            set retIdx $leftDestIdx
        } else {
            if {[$win compare $idx < insert]} {
                if {[$win compare $idx < "$rightDestIdx linestart"] || ([$win compare insert == $rightDestIdx] && [$win compare $idx == insert-1c])} {
                    set retIdx $leftDestIdx
                } else {
                    set retIdx $rightDestIdx
                }
            } else {
                if {[$win compare $idx > "$leftDestIdx lineend"] || ([$win compare insert == $leftDestIdx] && [$win compare $idx == insert+1c])} {
                    set retIdx $rightDestIdx
                } else {
                    set retIdx $leftDestIdx
                }
            }
        }
        
    }
    return $retIdx
}
proc keepCursorOffReadonly {win idx} {
    wcb::replace 0 0 [getNearestWritableIdx $win $idx]
}

# Only checks that neither the beginning nor the end of the selection
# is in a readonly region
proc keepSelectionOffReadonly {win args} {
    set newArgs {}
    foreach {from to} $args {
        lappend newArgs [getNearestWritableIdx $win $from]
        if {[string length $to] > 0} {
            lappend newArgs [getNearestWritableIdx $win $to]
        }
    }
    eval wcb::replace 0 [llength $args] $newArgs
}

# Returns whether the given range contains the given tag
proc doesRangeContainTag {win startIdx endIdx tag} {
    return [expr {
        ([llength [$win tag nextrange $tag $startIdx $endIdx]] > 0) ||
        ([lsearch [$win tag names $startIdx] $tag] >= 0) ||
        ([lsearch [$win tag names $endIdx-1c] $tag] >= 0)
    }]
}
proc isRangeContainedWithinTag {win startIdx endIdx tag} {
    set prev [$win tag prevrange $tag $endIdx]
    return [expr [$win compare [lindex $prev 0] <= $startIdx] && [$win compare [lindex $prev 1] >= $endIdx]]
}

proc isRangeSurroundedByReadonly {win startIdx endIdx} {
    return [expr ([lsearch [$win tag names $startIdx-1c] readonly] >= 0) && ([lsearch [$win tag names $endIdx] readonly] >= 0)]
}
proc protectReadonlyFmDel {win startIdx {endIdx ""}} {
    
    # Is a range of characters being deleted?
    if {[string length $endIdx] > 0} {
        # Yes.  Cancel the deletion of the range contains a readonly region
        if {[doesRangeContainTag $win $startIdx $endIdx readonly]} {
            wcb::cancel
        } elseif {[isRangeSurroundedByReadonly $win $startIdx $endIdx]} {
            $win tag add separator $startIdx "$startIdx lineend + 1c"
        }
    } else {
        # No--single character deletion.
        if {[lsearch [$win tag names $startIdx] readonly] >= 0} {
            wcb::cancel
        } elseif {[isRangeSurroundedByReadonly $win $startIdx $startIdx+1c]} {
            $win tag add separator $startIdx "$startIdx lineend + 1c"
        }
    }
}

# When all the text of a node is deleted, the readonly tag from
# the control and the readonly tag from the suffix "merge" together.
# This code ensures node text will not contain the readonly tag
proc removeReadonlyTag {win idx args} {
    if {[lsearch [$win mark names] remove-readonly-left] >= 0} {
        $win tag remove readonly remove-readonly-left remove-readonly-right
        $win tag remove separator remove-readonly-left "$idx lineend + 1 char"
        $win mark unset remove-readonly-left
        $win mark unset remove-readonly-right
    }
}
proc markInsertionPoint {win idx args} {
    $win mark unset remove-readonly-left
    $win mark unset remove-readonly-right
    if {[lsearch [$win tag names $idx] separator] >= 0} {
        $win mark set remove-readonly-left $idx
        $win mark gravity remove-readonly-left left
        $win mark set remove-readonly-right $idx
        $win mark gravity remove-readonly-right right
    }
}
proc checkCursorAfterDelete {win startIdx {endIdx ""}} {
    set idx [getNearestWritableIdx $win insert]
    $win mark set insert $idx
}
proc echo args {puts selset:$args}

proc setWidgetProtections {win} {
    if {[lsearch [wcb::callback $win before motion] [namespace current]::keepCursorOffReadonly] < 0} {
        wcb::cbappend $win before motion [namespace current]::keepCursorOffReadonly
        wcb::cbappend $win before selset [namespace current]::keepSelectionOffReadonly 
        wcb::cbappend $win before insert [namespace current]::markInsertionPoint
        wcb::cbappend $win after insert [namespace current]::removeReadonlyTag
        wcb::cbappend $win before delete [namespace current]::protectReadonlyFmDel
        wcb::cbappend $win after delete [namespace current]::checkCursorAfterDelete
    }
}

