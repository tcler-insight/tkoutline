if 0 {[%Useful highlight for bulletless outlines%]
    markup::addRule [textcmd] -regexp {\([0-9]+\)} -tag green
    markup::rehighlight [textcmd] 1.0 end
    text tag configure green -background {light green}
}
namespace eval tkoutline {
package require XOTcllite
set od [::xotcllite::Class create ::OutlineDocument]
$od instproc addBrowserCmd {} {
    # Make the outline document object accessible as a subcommand of the outline command
    my browser namespace export [namespace tail [self]]
    [my set outline] namespace import [self]
    [my set outline] rename [namespace tail [self]] document
}
$od instproc init {frame args} { #TODO
    my set modified 0
    trace variable [self]::modified w "[self] setTitle;#"
    trace variable [self]::fileName w "[self] setTitle;#"
    my set fileName ""
    set tree ""
    while {[llength $args] > 0} {
        switch -- [lindex $args 0] {
            -tree {
                set tree [lindex $args 1]
            }
            -filename {
                my set fileName [lindex $args 1]
            }
        }
        set args [lrange $args 2 end]
    }
    
    # Create the outline
    if {[string length $tree] == 0} {
        my set outline [outlinewidget::outline $frame.o]
    } else {
        my set outline [outlinewidget::outline $frame.o -tree $tree]
    }
    
    # Add the scrollbar and pack
    set text [[my set outline] textcmd]
    set sy $frame.sy
    $text configure -wrap word -yscrollcommand [list $sy set]
    scrollbar $sy -orient v -takefocus 0 -bd 1 -command [list $text yview]
    pack $sy -side right -fill y
    pack [my set outline] -fill both -expand 1
    
    # Event bindings
    foreach event {Save SaveAs SaveSubtree LoadSubtree ExtractSubtree} {
        bind $text <<$event>> "[self] $event"
    }
    foreach format [treeconvert::getExportFormatsList] {
        bind $text "<<ExportTo$format>>" "[self] ExportTo $format"
    }
    
    # Add a change indicator to an outlines title when something in the text widget changes
    wcb::cbappend $text after insert "[self] markModified"
    wcb::cbappend $text after delete "[self] markModified"
    
    # TODO: xotcllite should take care of this automatically ?
    return [self] 
    }
$od instproc outline args {eval [my set outline] $args}
$od instproc markModified args {my set modified 1}
$od instproc setTitle {args} { #TODO: can't seem to comment out the trace args.  Problem with xottcl evals?
    if {[string length [my set fileName]] == 0} {
        my set title Untitled
    } else {
        my set title [file tail [my set fileName]]
    }
    if {[my set modified]} {my append title " *"}
    }
$od instproc Save {{forcePrompt 0}} {
    set win [[my set outline] textcmd]
    set tree [[my set outline] treecmd]
    set fileName [my set fileName]
    
    # Contents of the text widget can be different from the data in the actual
    # tree structure, so sync the tree structure from the text widget
    # (the changed text is always saved to the tree as an idle callback, so 
    # there is only the slightest chance the text really needs to be saved
    # I guess maybe a call to update idletasks could be made here instead)
    outlinewidget::saveChangedTextToTree $win $tree
    if {([string length $fileName] == 0) || $forcePrompt} {
        set fileName [tk_getSaveFile]
        if {[string length $fileName] == 0} {return 0}
        my set fileName $fileName
    }
    ::tkoutline::saveTreeToFile $tree $fileName
    my set modified 0
    return 1
    }
$od instproc SaveAs {} {
    my Save 1
    my Raise
    }
$od instproc SaveSubtree {} {
    set o [my set outline]
    ::tkoutline::saveSubtreeToFile [$o textcmd] [$o treecmd] [$o getnode insert]
    }
$od instproc LoadSubtree {} {
    set fileName ""
    set outline [my set outline]
    set node [$outline getnode insert]
    set subtree [::tkoutline::getTreeFromFile $fileName]
    if {[string length $subtree] > 0} {
        set savedHeadline [$outline tree set $node title]
        outlinewidget::copySubtree $subtree [$outline tree rootname] [$outline treecmd] $node
        $outline tree set $node title $savedHeadline
        $subtree destroy
        }
    return
    }
$od instproc ExtractSubtree {} {
    set outline [my set outline]
    set node [$outline getnode insert]
    set fileName [string map {\[ "" \] ""} [$outline tree set $node title]]
    if {[file exists $fileName]} {
        set answer [tk_messageBox -message "$fileName already exists.  Do you want to replace it?" -type yesno]
        if {$answer == "no"} {return}
    }
    ::tkoutline::saveSubtreeToFile [$outline textcmd] [$outline treecmd] $node $fileName
    $outline tree set $node title "\[$fileName\]"
    foreach child [$outline tree children $node] {
        $outline tree delete $child
    }
    }
$od instproc ExportTo {format} {
    set outline [my set outline]
    set fileName [tk_getSaveFile -title "Save As $format" -filetypes [treeconvert::getFiletypesList $format]]
    if {[string length $fileName] == 0} {return}
    outlinewidget::saveChangedTextToTree [$outline textcmd] [$outline treecmd]
    treeconvert::export [$outline treecmd] $fileName $format
    }
$od instproc Raise {} {
    set fileName [my set fileName]
    focus [[my set outline] textcmd]
    if {[file isdir $fileName]} {
        cd $fileName
    } else {
        cd [file dirname $fileName]
        }
    }
$od instproc Close {} {
    if {[my set modified]} {
        set answer [tk_messageBox -message "Save [my set fileName] first?" -type yesnocancel]
        switch -- $answer {
            yes {
                if {[my Save]} {
                    set closeTree 1
                } else {
                    set closeTree 0
                }
            }
            no {
                set closeTree 1
            }
            cancel {
                set closeTree 0
            }
        }
    } else {
        set closeTree 1
    }
    return $closeTree
    }
}

