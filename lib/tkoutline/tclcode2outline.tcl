# View the given tkoutline source file in an outline
proc ::tkoutline::viewCodeAsOutline fileName {
    set fileName [file join $::tkoutline::topdir $fileName]
    set tree  [::treeconvert::import $fileName IndentedAscii]
    # Move all close braces to be subordinate to their open braces
    set demote {}
    $tree walk [$tree rootname] n {
        if {[$tree keyexists $n title]} {
            set cur [$tree set $n title]
            if {$cur == "\}"} {
                set prev [$tree previous $n]
                if {[string length $prev] > 0} {
                    if {[string index [$tree set $prev title] end] == "\{"} {
                        lappend demote $n
                        }
                    }
                }
            }
        }
    foreach node $demote {
        ::outlinewidget::demoteNode $tree $node
    }
    # Only display bullets on toplevel nodes and collapse all top level nodes
    $tree walk [$tree rootname] n {
        if {$n != [$tree rootname]} {
            if {[$tree parent $n] == [$tree rootname]} {
                $tree set $n expand 0
                if {([string length [$tree set $n title]] == 0) || ([string index [$tree set $n title] 0] == "#")} {
                    $tree set $n nobullet {}
                    }
            } else {
                $tree set $n nobullet {}
            }
        }
        }
    set od [::tkoutline::browser Open $fileName $tree]
    # Don't allow changes to be saved.  This will be a readonly outline
    $od proc Save {} {}
    $od proc markModified args {}
    
    # Highlight the descendents count portion of each node
    set textWin [$od outline textcmd]
    markup::addRule $textWin -regexp {\([0-9]+\)} -tag green
    markup::rehighlight $textWin 1.0 end
    $od outline text tag configure green -background {light green}
    
    # TODO: maybe disable wikilinks?
    # TODO: add a horizontal scrollbar or don't disable wrapping
    #$od outline text configure -wrap none
    }

