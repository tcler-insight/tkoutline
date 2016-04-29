namespace eval tkoutline {
package require XOTcllite
set ob [::xotcllite::Class create OutlineBrowser]
$ob instproc init {parentWin} {
    package require BWidget
    # This frame is used to bind some OutlineBrowser global events to
    my set nbframe $parentWin.f
    pack [frame [my set nbframe]] -expand 1 -fill both
    my set nb [my set nbframe].nb
    pack [NoteBook [my set nb]] -expand 1 -fill both
    foreach event {Open New Close Exit} {
        bind [my set nbframe] <<$event>> "[self] $event; break"
    }
    bind [my set nbframe] <<NextOutline>> "[self] Raise current+1"
    bind [my set nbframe] <<PrevOutline>> "[self] Raise current-1"

    wm protocol . WM_DELETE_WINDOW "event generate [my set nbframe] <<Exit>>"
    foreach importType {Opml IndentedAscii} {
        bind [my set nbframe] <<ImportFrom$importType>> "[self] ImportFrom $importType; break"
    }
    my set nextId 1
    }
$ob instproc addOutline {args} {
    set page page[my set nextId]
    my incr nextId
    set frame [[my set nb] insert end $page]
    set od [eval my OutlineDocument create $page $frame $args]
    
    # Make the outline browser object available as a subcommand of the outline document
    namespace eval [namespace parent [self]] namespace export [namespace tail [self]]
    $od namespace import [self]
    if {[namespace tail [self]] != "browser"} {
        rename ${od}::[namespace tail [self]] ${od}::browser
        }
    $od addBrowserCmd
    
    # TODO: Shouldn't be knowledge of the text widget here in this class
    set text [$od outline textcmd]
    bindtags $text [linsert [bindtags $text] 1 [my set nbframe]]
    my lappend outlines $od
    [my set nb] itemconfigure $page -raisecmd "$od Raise"
    [my set nb] itemconfigure $page -text [$od set title]
    [my set nb] raise $page
    #[my set nb] see $page ;# This doesn't seem to work the way I want
    if {[string length [option get [$od outline textcmd] wikimarkup Text]] > 0} {
        wikimarkup::setLinkJumpCmd [$od outline textcmd] "[self] jumpToWikiLink"
    }
    trace variable ${od}::title w "[my set nb] itemconfigure $page -text \[$od set title];#"
    return $od
    }
$ob instproc New {} {
    set od [my addOutline]
    $od outline selectnode [lindex [$od outline tree children root] 0]
    return $od
    }
$ob instproc jumpToWikiLink {file {anchor ""}} {
    if {[string length $file] > 0} {
        set od [my Open $file]
    } else {
        set od [my getoutline current]
    }
    if {[string length $anchor] > 0} {
        $od outline search $anchor
    }
}
$ob instproc Raise idx {
    set od [my getoutline $idx]
    if {[string length $od] > 0} {
        set page [namespace tail $od]
        [my set nb] raise $page
        [my set nb] see $page
        $od Raise
        }
    }
$ob instproc Open {{fname ""} {tree ""}} {
    if {[string length $fname] == 0} {
        set fname [tk_getOpenFile]
        } else {
        set fname [file join [pwd] $fname]
        }
    if {[string length $fname] > 0} {
        foreach page [[my set nb] pages] {
            set od [self]::$page
            if {[string compare $fname [$od set fileName]] == 0} {
                [my set nb] raise $page
                [my set nb] see $page
                $od Raise
                return $od
            }
        }
        cd [file dirname $fname]
        set glob [glob -nocomplain $fname]
        if {([llength $glob] > 1) || (([llength $glob] == 1) && [file exists [lindex $glob 0]])} {
            if {[llength $glob] == 1} {set fname [lindex $glob 0]}
            if {[string length $tree] == 0} {
                set od [my addOutline -filename $fname -tree [::tkoutline::getTreeFromFile $fname]]
            } else {
                set od [my addOutline -filename $fname -tree $tree]
            }
        } else {
            set od [my addOutline -filename $fname]
            $od outline selectnode [lindex [$od outline tree children root] 0]
        }
        return $od
    } else {
        return ""
    }
    }
$ob instproc Close {{od ""}} {
    if  {[string length $od] == 0} {
        set od [my getoutline current]
    }
    if {[$od Close]} {
        $od destroy
        set page [namespace tail $od]
        set nb [my set nb]
        set idx [expr [$nb index $page] - 1]
        if {$idx < 0} {set idx 0}
        $nb delete $page
        if {[llength [$nb pages]] > 0} {
            $nb raise [$nb page $idx]
        } else {
            # The last outline is closed focus on the notebook frame in order to activate the menu picks
            focus [my set nbframe]
        }
        return 1
    } else {
        return 0
    }
    }

$ob instproc CloseAll {} {
    set nb [my set nb]
    foreach page [$nb pages] {
        set od [self]::$page
        if {![my Close $od]} {
            return 0
        }
    }
    return 1
    }
$ob instproc Exit {} {
    if {[my CloseAll]} {
        exit
    }
    }
$ob instproc ImportFrom {importType} {
    set tree [::tkoutline::importOutline $importType]
    if {[string length $tree] > 0} {
        my addOutline -tree $tree
    }
    }
$ob instproc getoutline {idx} {
    if {[string match current* $idx]} {
        set page [[my set nb] raise]
        set idx [expr [string map [list current [[my set nb] index $page]] $idx]]
    }
    set page [[my set nb] pages $idx]
    if {[string length $page] > 0} {
        return [self]::$page
    } else {
        return ""
    }
    }
}

