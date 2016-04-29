namespace eval incrsearch {
variable history .search
variable inSearchMode 0
variable outline {}     ;# Only one outline at a time can be in search mode
variable savedBindtags {}
proc initSearchMode {} {
    variable history
    bind incrsearch <Escape> ::incrsearch::leaveSearchMode
    bind incrsearch <Key> {::incrsearch::incrSearch %A}
    bind incrsearch <BackSpace> ::incrsearch::backSearchUpOneChar
    if {![winfo exists $history]} {
        text $history
    }
}
proc enterSearchMode {outlineToSearch} {
    initSearchMode ;# Really only needed once per application lifetime
    variable inSearchMode
    if {$inSearchMode} leaveSearchMode
    set inSearchMode 1
    variable outline $outlineToSearch
    variable savedBindtags [bindtags [$outline textcmd]]
    bindtags [$outline textcmd] incrsearch
}
proc leaveSearchMode {} {
    variable inSearchMode 0
    variable outline
    variable savedBindtags
    variable history

    bindtags [$outline textcmd] $savedBindtags
    set searchStr [$history get "insert linestart" "insert lineend"]
   
    # Remove all the marks
    for {set x [expr [string length $searchStr] - 1]} {$x >= 0} {incr x -1} {
        $outline text mark unset search$x
    }
    $history insert insert \n
    $history mark set insert insert+1c
}
proc indicateFailedSearch {} {
    bell
}
proc incrSearch {str} {
    variable outline
    variable history
    foreach char [split $str {}] {
        $history insert insert $char
        $history mark set insert insert+1c
        set searchStr [$history get "insert linestart" "insert lineend"]
        $outline text mark set search[string length $searchStr] insert 
        set match [$outline search $searchStr]
        if {[llength $match] == 0} indicateFailedSearch else {
            $history mark set match "insert lineend"
        }
    }
}
proc backSearchUpOneChar {} {
    variable outline
    variable history
    if {[$history compare insert > "insert linestart"]} {
        $history delete insert-1c
        set matchStr ""
        catch {set matchStr [$history get "insert linestart" match]}        
        set searchStr [$history get "insert linestart" "insert lineend"]
        set mark search[expr [string length $searchStr] + 1]
        $outline text tag remove sel 1.0 end
        $outline text mark set insert $mark
        $outline text tag add sel insert insert+[string length $matchStr]c
        $outline text mark unset $mark
    }
}
proc searchAgain {} {
    variable outline
    variable history
    $outline text mark set insert insert+1c
    set match [$outline search [$history get "insert linestart" "insert lineend"]]
    if {[llength $match] == 0} indicateFailedSearch else {
        $history mark set match "insert lineend"
    }
}
}
