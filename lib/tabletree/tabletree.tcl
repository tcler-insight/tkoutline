proc firstVisibleLine {win} {
    return [lindex [split [$win index @0,0] .] 0]
}
proc lastVisibleLine {win} {
    return [lindex [split [$win index @0,[winfo height $win]] .] 0]
}

# The y coordinate where the last pixel of text is displayed
proc getAdjustedHeight {win} {
    #return [expr ([winfo height $win] - [$win cget -borderwidth]) - [$win cget -pady] ]
    set idx [$win index @[winfo width $win],[winfo height $win]]
    lassign [$win dlineinfo $idx] x y w h
    return [expr $y + $h]
}

# Returns a list of alternating line numbers and corresponding
# line heights in pixels of that line number for all lines
# currently in the display of the given text widget
proc getLineHeights {win} {
    if {![winfo ismapped $win]} {return {}}

    # Only compute for lines within the visible display area
    set curLine [firstVisibleLine $win] 
    set lastLine [lastVisibleLine $win]
    lassign [$win dlineinfo $curLine.0] x y 
    while {$curLine < $lastLine} {
        set prevY $y
        incr curLine
        lassign [$win dlineinfo $curLine.0] x y 
        lappend heights [expr $curLine - 1] [expr $y - $prevY]
    }
    lappend heights $curLine [expr [getAdjustedHeight $win] - $y]
    return $heights
}
proc getLineHeights {win} {
    if {![winfo ismapped $win]} {return {}}
    set saveY [lindex [$win yview] 0]

    # Only compute for lines within the visible display area
    set firstLine [firstVisibleLine $win] 
    set lastLine [lastVisibleLine $win]
    for {set l $firstLine} {$l <= $lastLine} {incr l} {
        lappend heights $l [getLineHeight $win $l]
    }
    $win yview moveto $saveY
    return $heights
}
proc getLineHeight {win line} {
    $win see "$line.0 lineend+1c"
    $win see $line.0
    lassign [$win dlineinfo $line.0] x y1 
    lassign [$win dlineinfo "$line.0 lineend+1c"] x y2 
    if {[string length $y2] == 0} {
        set y2 [getAdjustedHeight $win]
    }
    return [expr $y2 - $y1]
}
proc getSpacing {win lineNum} {
    set tags [$win tag names $lineNum.0]
    set idx [lsearch $tags spacing*]
    if {$idx >= 0} {
        return [$win tag cget [lindex $tags $idx] -spacing3]
    } else {
        return 0
    }
}
proc removeSpacingTags {t lineNum} {
    foreach tag [$t tag names $lineNum.0] {
        if {[string match spacing* $tag]} {
            $t tag remove $tag $lineNum.0 "$lineNum.0 lineend"
        }
    }
}
proc setSpacing {t lineNum pixels} {
    removeSpacingTags $t $lineNum
    $t tag add spacing$pixels $lineNum.0 "$lineNum.0 lineend + 1c"
    $t tag configure spacing$pixels -spacing3 $pixels
}
proc syncLineHeights {t1 t2} {
    foreach {l1 h1} [getLineHeights $t1] {l2 h2} [getLineHeights $t2] {
        if {$h1 != $h2} {
            #set s1 [getSpacing $t1 $l1]
            set s2 [getSpacing $t2 $l2]
            #puts "$l1: $h1, $h2, $s2"
            #if {$h1 > $h2 - $s2} {
                setSpacing $t2 $l2 [expr $h1 - ($h2 - $s2)]
            #} else {
            #    setSpacing $t1 $l1 [expr $h2 - $h1]
            #}
        }
    }
    return
}
proc syncLineHeights {t1 t2} {
    set saveY [lindex [$t2 yview] 0]
    foreach {l1 h1} [getLineHeights $t1] {
        set l2 $l1
        set h2 [getLineHeight $t2 $l2]
        if {$h1 != $h2} {
            set s2 [getSpacing $t2 $l2]
            setSpacing $t2 $l2 [expr $h1 - ($h2 - $s2)]
        }
    }
    $t2 yview moveto $saveY
    return
}
