# markup.tcl --
#
#     Syntax highlighting for the Tk text widget
#
# Copyright (C) 2002  Brian P. Theado
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
package require wcb
namespace eval markup {
    namespace export addRule removeRule rehighlight enableHighlighting flashTag

proc getTagRange {win tag index} {
    set indices [$win tag prevrange $tag $index]
    if {([llength $indices] == 0) || 
        [$win compare [lindex $indices 1] < $index]} {
        set indices [$win tag nextrange $tag $index]
        }
    return $indices
}
proc tagUntilLeaveEvent {win tag startIdx endIdx} {
    $win tag raise $tag
    $win tag add $tag $startIdx $endIdx
    $win tag bind $tag <Any-Leave> \
        "$win tag remove $tag $startIdx $endIdx;\
         event generate $win <Enter>"
}

# Configures the given tag so that any mouseover event 
# will cause the given flashtag to be applied until the 
# mouse leaves the tag
proc flashTag {win tag flashTag} {
    $win tag bind $tag <Any-Enter> "eval ::markup::tagUntilLeaveEvent $win $flashTag \[::markup::getTagRange $win $tag @%x,%y]"
}

# Use marks instead of a tag because there may be no text in
# the widget to tag (i.e. before the first insert)
proc markRange {win startIdx endIdx} {
    $win mark set rehighlight:left $startIdx
    $win mark gravity rehighlight:left left
    $win mark set rehighlight:right $endIdx
    $win mark gravity rehighlight:right right
}
proc markInsertLine {win idx args} {
    if {![isHighlightInProgress $win]} {
        set startIdx "$idx linestart"
        set endIdx "$idx lineend"
        markRange $win $startIdx $endIdx
    }
}
proc markDelLine {win idx1 {idx2 ""}} {
    set idx1 [$win index "$idx1 linestart"]
    if {[string length $idx2] == 0} {
        set idx2 "$idx1 lineend"
    } else {
        set idx2 [$win index "$idx2 lineend"]
    }
    markRange $win $idx1 $idx2
}
proc isHighlightInProgress {win} {
    return [expr [lsearch [$win mark names] rehighlight:in_progress] >= 0]
}
proc rehighlightMarkedRange {win} {
    if {![isHighlightInProgress $win]} {
        $win mark set rehighlight:in_progress end
        rehighlight $win rehighlight:left rehighlight:right
        $win mark unset rehighlight:in_progress
        $win mark unset rehighlight:left
        $win mark unset rehighlight:right
    }
}
proc suspend {win} {
    $win mark set rehighlight:in_progress end
}
proc resume {win} {
    $win mark unset rehighlight:in_progress
}
proc enableHighlighting {win} {
    if {[lsearch [wcb::callback $win before insert] ::markup::markInsertLine] < 0} {
        wcb::cbappend $win before insert ::markup::markInsertLine
        wcb::cbappend $win after insert ::markup::rehighlightWrapper
        wcb::cbappend $win before delete ::markup::markDelLine
        wcb::cbappend $win after delete ::markup::rehighlightWrapper
    }
}
proc unhighlight {win startIdx endIdx} {
    variable patterns

    # Construct a list of tags to remove
    set tags {}
    foreach key [array names patterns $win,*] {
        array set p $patterns($key)
        set tags [concat $tags $p(tag) $p(auxTags)]
        unset p
    }

    # Remove the tags
    foreach tag $tags {
        $win tag remove $tag $startIdx $endIdx
    }
}
proc rehighlight {win startIdx endIdx} {
    variable patterns

    # Convert indices to numbers in case any callback modifies text and causes
    # any mark based indices to be deleted
    set startIdx [$win index $startIdx]
    set endIdx [$win index $endIdx]
    unhighlight $win $startIdx $endIdx
    foreach key [array names patterns $win,*] {
        set pattern [string range $key [expr [string first , $key] + 1] end]
        array set p $patterns($key)
        if {$p(regexp)} {
            set opts {-regexp -count len}
        } else {
            set opts ""
            set len [string length $pattern]
        }

        # Find all matches for the current pattern
        set matchIdxs {}
        set idx [eval $win search -elide $opts [list $pattern $startIdx $endIdx+1c]]
        #puts "idx: $idx, opts: $opts, pattern:$pattern"
        while {[string length $idx] > 0} {
            lappend matchIdxs $idx $idx+${len}c
            set idx [eval $win search -elide $opts [list $pattern $idx+[expr $len]c $endIdx+1c]]
        #puts "l:idx: $idx, opts: $opts, pattern:$pattern"
            }

        # Apply tags to each of the matches found
        foreach {matchStart matchEnd} $matchIdxs {
            if {[string length $p(tag)] > 0} {
                $win tag add $p(tag) $matchStart $matchEnd
                }
            if {[string length $p(callback)] > 0} {
                set p(auxTags) [eval [concat $p(callback) $win $matchStart $matchEnd]]
                set patterns($key) [array get p]
            }
        }
        unset p
    }
}
proc rehighlightWrapper {win args} {
    # Remove the underscore from the window name
    set origWin [string range [namespace tail $win] 1 end]
    rehighlightMarkedRange $origWin
    }
proc addRule {win args} {
    variable patterns
    if {[lindex $args 0] == "-regexp"} {
        set p(regexp) 1
        set args [lrange $args 1 end]
    } else {
        set p(regexp) 0
    }
    set pattern [lindex $args 0]
    set args [lrange $args 1 end]
    set p(tag) {}
    set p(callback) {}
    set p(auxTags) {}
    switch -- [lindex $args 0] {
        -tag {set p(tag) [lindex $args 1]}
        -callback {set p(callback) [lindex $args 1]}
        default {error "[lindex $args 0] should be -tag or -callback"}
    }
    if {[llength [array names pattern $win*]] == 0} {
        bind $win <Destroy> "+::markup::removeRules %W"
    }
    set patterns($win,$pattern) [array get p]
}
proc removeRules {win} {
    variable patterns
    foreach key [array names patterns $win*] {
        unset patterns($key)
    }
}
proc removeRule {win pattern} {
    variable patterns
    unset patterns($win,$pattern)
}
}
package provide markup 0.1

