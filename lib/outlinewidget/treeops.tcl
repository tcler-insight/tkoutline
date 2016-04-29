# Tkoutline - an outline editor.
# Copyright (C) 2001-2002  Brian P. Theado
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
namespace eval outlinewidget {
package require Tk
package require struct
package require treeconvert

# Override the existing create function
if 0 {
catch {rename createTextTree _createTextTree}
proc createTextTree {win tree} {
    _createTextTree $win $tree
    initTreeObservation $win $tree
    return
}
}
# Override the existing function in treedisplay.tcl
proc configureOutlineBulletStateTags {outline} {
    set win [$outline textcmd]
    set tree [$outline treecmd]
    $win tag bind leaf <<Click>> ""
    $win tag bind collapsed <<Click>> "[namespace current]::expandNode $tree \[$outline getnode @%x,%y]"
    $win tag bind expanded <<Click>> "[namespace current]::collapseNode $tree \[$outline getnode @%x,%y]"
}
proc collapseNode {tree node} {
    $tree set $node expand 0
    #$win mark set insert [getNodeTextStartIdx $node]
}
proc expandNode {tree node} {
    $tree set $node expand 1
    #$win mark set insert [getNodeTextStartIdx $node]
}

proc demoteNode {tree node} {
    set prev [$tree previous $node]
    if {[llength $prev] > 0} {
        if {(![$tree set $prev expand]) && ![$tree isleaf $prev]} {
            expandNode $tree $prev
        }
        $tree move $prev [$tree numchildren $prev] $node
    }
}

proc promoteNode {tree node} {
    set parent [$tree parent $node]
    if {[string compare $parent [$tree rootname]] != 0} {
        $tree move [$tree parent $parent] [expr [$tree index $parent] + 1] $node
    }
}

# Move the given source node to just before the given target node
proc moveNodeBefore {tree srcNode targetNode} {
    if {[string compare $srcNode $targetNode] != 0} {
        set targetParent [$tree parent $targetNode]
        set srcParent [$tree parent $srcNode]
        $tree move $targetParent [$tree index $targetNode] $srcNode
        return 1
    } else {
        return 0
    }
}
proc moveNodeUp {tree node} {
    set prev [$tree previous $node]
    if {[llength $prev] > 0} {
        $tree move [$tree parent $node] [$tree index $prev] $node
    }
}
proc moveNodeDown {tree node} {
    set next [$tree next $node]
    if {[llength $next] > 0} {
        $tree move [$tree parent $node] [$tree index $next] $node
    }
}

proc deleteNode {tree node} {
    if {[$tree numchildren $node] > 0} {
        # Until undo is implemented, warn the user if more than one node is to be deleted
        set answer [tk_messageBox -message "Delete node and all its children?" -type yesno]
        switch -- $answer {
        yes {
            $tree delete $node
        }
        no {}
        }
    } else {
        $tree delete $node
    }
}

proc selectNodeText {win node} {
    $win tag remove sel 1.0 end
    $win tag add sel \
        [listitem::index $win $node.text.first] \
        [listitem::index $win $node.text.last]
    $win mark set insert [listitem::index $win $node.text.last] 
    $win see insert
}

# Splits the given node into two sibling nodes at the given text
# widget index
proc splitNode {win tree idx} {
    set idx [$win text index $idx]
    set node [$win getnode $idx]
    if {[$win text compare $idx == [$win getendidx $node]]} {
        if {![$tree set $node expand]} {
            $win selectnode [insertEmptySiblingNode $tree $node]
        } else {
            set newNode [$tree insert [$tree parent $node] [expr [$tree index $node] + 1]]
            #$tree set $newNode $newNode
            eval $tree move $newNode 0 [$tree children $node]
            $tree set $newNode expand 1
            $tree set $node expand 0
            $win selectnode $newNode
        }
    } elseif {[$win text compare $idx == [$win getstartidx $node]]} {
        $win selectnode [insertEmptySiblingNode $tree $node before]
    } else {
        set text1 [$win text get [$win getstartidx $node] $idx]
        set text2 [$win text get $idx [$win getendidx $node]]
        set newNode [$tree insert [$tree parent $node] [$tree index $node]]
        $tree set $node title $text2
        $tree set $newNode title $text1
        $win text mark set insert [$win getstartidx $node]
    }
    return
}

proc mergeNodes {tree node1 node2} {
    # Move children of node2 to node1
    if {[$tree numchildren $node2] > 0} {
        eval $tree move $node1 [$tree numchildren $node1] [$tree children $node2]
        $tree set $node1 expand 1
    }

    # Append text from node2 to end of node1
    $tree set $node1 title "[$tree set $node1 title] [$tree set $node2 title]"

    # Delete node2
    $tree delete $node2
}

proc mergeNodeRight {win idx} {
    set node [$win getnode $idx]
    if {([$win text compare $idx == [$win getendidx $node]]) && ([string length [$win text tag nextrange sel 1.0 end]] == 0)} {
        set nextNode [$win getnextvisiblenode $node]
        if {[string length $nextNode] > 0} {
            set offset [string length [$win tree set $node title]]
            mergeNodes [$win treecmd] $node $nextNode
            $win text mark set insert [$win getstartidx $node]+${offset}c
            }
        }
    }
proc mergeNodeLeft {win idx} {
    set node [$win getnode $idx]
    if {([$win text compare $idx == [$win getstartidx $node]]) && ([string length [$win text tag nextrange sel 1.0 end]] == 0)} {
        set prevNode [$win getprevvisiblenode $node]
        if {[string length $prevNode] > 0} {
            set offset [expr [string length [$win tree set $prevNode title]] + 1]
            mergeNodes [$win treecmd] $prevNode $node
            $win text mark set insert [$win getstartidx $prevNode]+${offset}c
            }
        }
    }

proc insertEmptySiblingNode {tree node {where after}} {
    set idx [$tree index $node]
    if {$where == "after"} {incr idx}
    set n [$tree insert [$tree parent $node] $idx]
    #$tree set $n $n
    return $n
}

proc insertEmptyChildNode {tree node} {
    set n [$tree insert $node [$tree numchildren $node]]
    #$tree set $n $n
    $tree set $node expand 1
    return $n
}
proc getExpandLevel {tree node} {
    set deepest [$tree depth $node]
    $tree walk $node n {
        if {![$tree set $n expand]} {
            if {[$tree depth $n] > $deepest} {
                set deepest [$tree depth $n]
            }
            
            # prune
            ::struct::prune
        }
    }
    return [expr $deepest - [$tree depth $node]]
}
proc increaseExpandLevel {tree {node ""}} {
    if {[string length $node] == 0} {set node [$tree rootname]}
    hideChildrenBelowLevel [expr [getExpandLevel $tree $node] + 1] $tree $node
}
proc decreaseOutlineExpandLevel {outline {node ""}} {
    # By default, if the node with the insertion cursor goes away, then the
    # cursor will end up on the node following.  Here it is desirable for the
    # cursor to move to the parent, so multiple Alt-minus will affect the same
    # lineage.
    if {[string length $node] == 0} {set node [$tree rootname]}
    set curNode [$outline getnode insert]
    decreaseExpandLevel [$outline treecmd] $node
    if {![listitem::exists [$outline textcmd] $curNode]} {
        set parent [$outline tree parent $curNode]
        $outline text mark set insert [listitem::index [$outline textcmd] $parent.text.last]
    }
    
}
proc decreaseExpandLevel {tree {node ""}} {
    if {[string length $node] == 0} {set node [$tree rootname]}
    if {![$tree set $node expand]} {
        set node [$tree parent $node]
    }
    set newLevel [expr [getExpandLevel $tree $node] - 1] 
    set startDepth [$tree depth $node]
    $tree walk $node n {
        set depth [expr [$tree depth $n] - $startDepth]
        if {$depth == $newLevel} {
            $tree set $n expand 0
        }
        if {![$tree set $n expand]} {
            ::struct::prune
        }
    }
}

# Sets the expansion level of the tree
proc hideChildrenBelowLevel {level tree {node ""}} {
    if {[string length $node] == 0} {set node [$tree rootname]}
    set startDepth [$tree depth $node]

    # For performance reasons (minimize text widget calls),
    # collapse on the way down the tree and expand on the way
    # back up.
    $tree walk $node -order both {a n} {
        set depth [expr [$tree depth $n] - $startDepth]
        switch $a {
            leave {
                if {$depth < $level} {
                    if {![$tree isleaf $n]} {
                        $tree set $n expand 1
                    }
                } 
            }
            enter {
                if {$depth == $level} {
                    $tree set $n expand 0
                }
            }
        }
    }
}

# Copy srcNode and all descendents to child of dstNode in dstTree
proc copySubtree {srcTree srcNode dstTree dstNode} {
    foreach key [$srcTree keys $srcNode] {
        $dstTree set $dstNode $key [$srcTree set $srcNode $key]
    }
    foreach child [$srcTree children $srcNode] {
        set newChild [$dstTree insert $dstNode [$dstTree numchildren $dstNode]]
        copySubtree $srcTree $child $dstTree $newChild
    }
}
proc duplicateSubtree {tree node} {
    set newNode [duplicateNode $tree $node]
    copySubtree $tree $node $tree $newNode
    return $newNode
}
proc duplicateNode {tree node} {
    set newNode [insertEmptySiblingNode $tree $node before]
    $tree set $newNode title [$tree set $node title]
    return $newNode
}
proc toggleBulletOnOff {tree node} {
    if {[$tree keyexists $node nobullet]} {
        $tree unset $node nobullet
    } else {
        $tree set $node nobullet ""
    }
}
proc nodeToAscii {tree node {startDepth 1}} {
    set indent "[string repeat {    } [expr [$tree depth $node] - $startDepth]]" 
    return "$indent[$tree set $node title]"
    }
proc nodesToAscii {tree nodes} {
    # Get the minimum indent for these nodes
        set minDepth 200000
        foreach node $nodes {
            set depth [$tree depth $node]
            if {$depth < $minDepth} {
                set minDepth $depth
            }
        }
    set text {}
    foreach node $nodes {
        if {[$tree set $node expand]} {
            # The node is expanded, so only get the text for that node
                lappend text [nodeToAscii $tree $node $minDepth]
            } else {
                # The node is collapsed.  Retreive the text for descendents
                $tree walk $node n { 
                    lappend text [nodeToAscii $tree $n $minDepth]
                }
                }
            }
        if {[llength $text] == 1} {
            return [lindex $text 0]\n
        } else {
            return [join $text \n]
            }
    }
proc evalDescendentsAsScript {tree node} {
    set script {}
    $tree walk $node n {
        if {"$n" != $node} {
            append script [nodeToAscii $tree $n]\n
        }
    }
    return [[winfo parent [focus -lastfor .]] eval $script]
}
proc isNodeTextASelectionSubset {outline node} {
    set win [$outline textcmd]
    return [expr \
        [$win compare sel.first <= [$outline getstartidx $node]] && \
        [$win compare sel.last >= [$outline getendidx $node]]]
}
proc cutSelectionToClipboard {outline} {
    set win [$outline textcmd]
    set nodes [listitem::itemsWithTag $win sel]
    if {[llength $nodes] > 0} {
        if {([llength $nodes] == 1) && ![isNodeTextASelectionSubset $outline [lindex $nodes 0]]} {
            set data [$win get sel.first sel.last]
            $win delete sel.first sel.last
        } else {
            set data [nodesToAscii [$outline treecmd] $nodes]
            foreach node $nodes {
                if {[$outline tree set $node expand]} {
                    $outline tree cut $node
                } else {
                    $outline tree delete $node
                    }
            }
        }
        clipboard clear -displayof $win
        clipboard append -displayof $win $data
    }
}
proc copySelectionToClipboard {outline} {
    set win [$outline textcmd]
    set nodes [listitem::itemsWithTag $win sel]
    if {[llength $nodes] > 0} {
        if {([llength $nodes] == 1) && ![isNodeTextASelectionSubset $outline [lindex $nodes 0]]} {
            set data [$win get sel.first sel.last]
        } else {
            set data [nodesToAscii [$outline treecmd] $nodes]
        }
        clipboard clear -displayof $win
        clipboard append -displayof $win $data
    }
}
proc pasteText {outline node text} {
    set nextNode [$outline getnextvisiblenode $node]
    if {[string length $nextNode] > 0} {
        if {[$outline tree depth $nextNode] < [$outline tree depth $node]} {
            set parent [$outline tree parent $node]
            set idx [expr [$outline tree index $node] + 1]
        } else {
            set parent [$outline tree parent $nextNode]
            set idx [$outline tree index $nextNode]
        }
    } else {
        set parent [$outline tree parent $node]
        set idx [expr [$outline tree index $node] + 1]
    }
    treeconvert::textToTree $text [$outline treecmd] $parent $idx
}
proc pasteTextFromClipboard {outline node} {
    if {![catch {selection get -displayof $outline -selection CLIPBOARD} text]} {
        if {[llength [split $text \n]] > 1} {
            pasteText $outline $node $text
            return 1
        } else {
            # Fall through to the default paste handler
            return 0
        }
    } else {
        return 0
    }
}
proc ::outlinewidget::gotoParent {outline node} {
    set parent [$outline tree parent $node]
    if {([string length $parent] > 0) && ($parent != [$outline tree rootname])} {
        $outline text mark set insert [$outline getstartidx $parent]
        $outline text see insert
    }
    return $parent
}
proc findOrInsertPath {tree parent idx path args} {
    set path [concat $path $args]
    set step $path
    foreach step $path {
        set found 0
        foreach sibling [$tree children $parent] {
            if {[string match $step [$tree set $sibling title]]} {
                set found 1
                set n $sibling
                break
            }
        }
        if {!$found} {
            set n [$tree insert $parent $idx]
            $tree set $n title $step
        }
    set parent $n
    }
    return $n
    }


proc getNewTree {} {
    set t [::struct::tree]
    namespace export [namespace tail $t]
    namespace eval :: "namespace import $t"
    $t set [$t rootname] expand 1
    set node [$t insert [$t rootname] 0]
    $t set $node title $node
    $t set $node expand 0
    return [namespace tail $t]
}
proc mapKeysToEvents {eventList} {
    foreach event $eventList {
        set optName "[string tolower [string index $event 0]][string range $event 1 end]Key"
        set key [option get . $optName ""]
        eval event add <<$event>> $key 
    }
}
foreach {opt key} {
    *dragStartKey <ButtonPress-1>
    *dragMotionKey <B1-Motion>
    *dragStopKey <ButtonRelease-1>
    *clickKey <ButtonPress><ButtonRelease>
    *demoteKey <Control-Right>
    *promoteKey <Control-Left>
    *nodeUpKey <Control-Up>
    *nodeDownKey <Control-Down>
    *insertChildKey <Insert>
    *insertSiblingKey <Control-Insert>
    *splitNodeKey <Return>
    *mergeNodeRightKey <Delete>
    *mergeNodeLeftKey <BackSpace>
    *deleteNodeKey <Control-Delete>
    *toggleBulletKey <Control-b>
    *expandKey <Meta-e>
    *collapseKey <Meta-c>
    *duplicateNodeKey <Meta-n>
    *duplicateSubtreeKey <Meta-s>
    *increaseExpandKey <Alt-equal>
    *decreaseExpandKey <Alt-minus>
    *increaseExpandGlobalKey <Control-equal>
    *decreaseExpandGlobalKey <Control-minus>
    *gotoParentKey <Control-p>
    *toggleMagicButtonKey <Control-m>
} {
    option add $opt $key widget
}
switch $tcl_platform(platform) {
    windows {
        option add *showAllAtCurrentKey <Control-`> widget
    }
    default {
        option add *showAllAtCurrentKey <Control-grave> widget
    }
}
mapKeysToEvents { 
        DragStart
        DragMotion
        DragStop
        Click
        Demote
        Promote
        NodeUp
        NodeDown
        InsertChild
        InsertSibling
        SplitNode
        MergeNodeRight
        MergeNodeLeft
        DeleteNode
        ToggleBullet
        DuplicateNode
        DuplicateSubtree
        ShowAllAtCurrent
        IncreaseExpand
        DecreaseExpand
        IncreaseExpandGlobal
        DecreaseExpandGlobal
        ToggleMagicButton
        GotoParent
    }
proc setupOutlineMenu {menu} {
    # The menu picks will generate events on the window that currently has focus
    set winCmd {[focus -lastfor .]}
    $menu configure -postcommand "::tkoutline::setMenuEntryStates $menu $winCmd"
    $menu add command -label "Insert Child" -underline 0 -command "event generate $winCmd <<InsertChild>>" -accelerator [::tkoutline::describeEvent <<InsertChild>>]
    $menu add command -label "Insert Sibling" -underline 1 -command "event generate $winCmd <<InsertSibling>>" -accelerator [::tkoutline::describeEvent <<InsertSibling>>]
    $menu add command -label "Delete" -underline 0 -command "event generate $winCmd <<DeleteNode>>" -accelerator [::tkoutline::describeEvent <<DeleteNode>>]
    $menu add separator
    $menu add command -label "Duplicate node" -underline 10 -command "event generate $winCmd <<DuplicateNode>>" -accelerator [::tkoutline::describeEvent <<DuplicateNode>>]
    $menu add command -label "Duplicate subtree" -underline 10 -command "event generate $winCmd <<DuplicateSubtree>>" -accelerator [::tkoutline::describeEvent <<DuplicateSubtree>>]
    $menu add separator
    $menu add command -label "Move Up" -underline 5 -command "event generate $winCmd <<NodeUp>>" -accelerator [::tkoutline::describeEvent <<NodeUp>>]
    $menu add command -label "Move Down" -underline 6 -command "event generate $winCmd <<NodeDown>>" -accelerator [::tkoutline::describeEvent <<NodeDown>>]
    $menu add command -label "Promote" -underline 0 -command "event generate $winCmd <<Promote>>" -accelerator [::tkoutline::describeEvent <<Promote>>]
    $menu add command -label "Demote" -underline 2 -command "event generate $winCmd <<Demote>>" -accelerator [::tkoutline::describeEvent <<Demote>>]
    $menu add separator
    $menu add command -label "Increase expansion" -underline 2 -command "event generate $winCmd <<IncreaseExpand>>" -accelerator [::tkoutline::describeEvent <<IncreaseExpand>>]
    $menu add command -label "Decrease expansion" -underline 0 -command "event generate $winCmd <<DecreaseExpand>>" -accelerator [::tkoutline::describeEvent <<DecreaseExpand>>]
    menu $menu.rootlevel
    foreach level {1 2 3 4 5 6 7 8 9} {
        $menu.rootlevel add command -label $level -underline 0 -command "event generate $winCmd <Control-Key-$level>" -accelerator "Ctrl-$level"
    }
    $menu add cascade -label "Show levels below root" -underline 18 -menu $menu.rootlevel
    menu $menu.currentlevel
    foreach level {0 1 2 3 4 5 6 7 8 9} {
        $menu.currentlevel add command -label $level -underline 0 -command "event generate $winCmd <Alt-Key-$level>" -accelerator "Alt-$level"
    }
    $menu add cascade -label "Show levels below current" -underline 5 -menu $menu.currentlevel
    $menu add command -label "Show all at current level" -underline 5 -command "event generate $winCmd <<ShowAllAtCurrent>>" -accelerator [::tkoutline::describeEvent <<ShowAllAtCurrent>>] 
    bind . <Button-3> "tk_popup $menu %X %Y"
}

# Setup the console so commands are executed within
# context of the current outline.  The effect is that the methods
# of the outline can be called directly without calling the object
proc setupConsoleForEasyOutlineAccess {} {
    if {[llength [console eval {info commands ::_consoleinterp}]] == 0} {
    console eval [list proc object name {proc $name args "namespace eval $name \$args"}]
    console eval {rename ::consoleinterp ::_consoleinterp}

    console eval {object ::consoleinterp}
    console eval {
        consoleinterp proc _curOutline {} {
        return [_consoleinterp eval {winfo parent [focus -lastfor .]}]
        }
    }
    console eval {consoleinterp proc eval {str} {::_consoleinterp eval $str}}
    console eval {
        consoleinterp proc record {str} {
            ::_consoleinterp eval "history add [list [string trimright $str]]"
            ::_consoleinterp eval "catch {[_curOutline] eval [list [string trimright $str]]} retVal; set retVal"
            }
        }
    }
}
variable consoleCompatFile [file join [file dirname [info script]] console.tcl]
proc showConsole {} {
    variable consoleCompatFile
    # Unix doesn't have the console command, so source in this 
    # compatibility file from donald porter
    uplevel #0 source [list $consoleCompatFile]
    setupConsoleForEasyOutlineAccess
}

proc bindCoreOutlineEvents {} {

    # Debug and scripting access. 
    bind Outline <F2> [namespace current]::showConsole

    # Node movement bindings
    foreach {event actionProc} {
        <<Demote>> demoteNode
        <<Promote>> promoteNode
        <<NodeUp>> moveNodeUp
        <<NodeDown>> moveNodeDown
    } {
	bind Outline $event "\
		set node \[%W getnode insert];\
		[namespace current]::$actionProc \[%W treecmd] \$node;\
		%W text see insert; break"
    }
    # node insertion bindings
    foreach {event actionProc} {
        <<InsertSibling>> insertEmptySiblingNode
        <<InsertChild>> insertEmptyChildNode
    } {
        bind Outline $event "%W selectnode \[[namespace current]::$actionProc \[%W treecmd] \[%W getnode insert]]; break"
    }
    foreach {event actionProc} {
        <<DuplicateNode>> duplicateNode
        <<DuplicateSubtree>> duplicateSubtree
    } {
        bind Outline $event "[namespace current]::$actionProc \[%W treecmd] \[%W getnode insert]; break"
    }
    bind Outline <<Paste>> "if {\[[namespace current]::pasteTextFromClipboard %W \[%W getnode insert]]} break"

    # Tkoutline's default key for insertSibling is <Control-Insert>
    # On windows <<Copy>> is bound to both <Control-c> and <Control-Insert>
    # Delete <Control-Insert> from <<Copy>> so insert sibling will work
    event delete <<Copy>> <Control-Insert>
    bind Outline <<Copy>> "[namespace current]::copySelectionToClipboard %W; break"
    bind Outline <<Cut>> "[namespace current]::cutSelectionToClipboard %W; break"

    bind Outline <<ToggleBullet>> "[namespace current]::toggleBulletOnOff \[%W treecmd] \[%W getnode insert]"
    bind Outline <<DeleteNode>> "[namespace current]::deleteNode \[%W treecmd] \[%W getnode insert]; break"
    bind Outline <<SplitNode>> "[namespace current]::splitNode %W \[%W treecmd] insert; break"
    bind Outline <<MergeNodeRight>> "[namespace current]::mergeNodeRight %W insert"
    bind Outline <<MergeNodeLeft>> "[namespace current]::mergeNodeLeft %W insert"
    bind Outline <Button-3> "%W text mark set insert @%x,%y"

    bind Outline <<IncreaseExpand>> "[namespace current]::increaseExpandLevel \[%W treecmd] \[%W getnode insert]"
    bind Outline <<DecreaseExpand>> "[namespace current]::decreaseOutlineExpandLevel %W \[%W getnode insert]"
    bind Outline <<IncreaseExpandGlobal>> "[namespace current]::increaseExpandLevel \[%W treecmd] \[%W tree rootname]"
    bind Outline <<DecreaseExpandGlobal>> "[namespace current]::decreaseOutlineExpandLevel %W \[%W tree rootname]"
    foreach key {1 2 3 4 5 6 7 8 9} {
        bind Outline <Control-Key-$key> "[namespace current]::hideChildrenBelowLevel $key \[%W treecmd]"
    }
    bind Outline <<ShowAllAtCurrent>> "[namespace current]::hideChildrenBelowLevel \[%W tree depth \[%W getnode insert]] \[%W treecmd]"
    foreach key {0 1 2 3 4 5 6 7 8 9} {
        bind Outline <Alt-Key-$key> "[namespace current]::hideChildrenBelowLevel $key \[%W treecmd] \[%W getnode insert]"
    }
    bind Outline <<GotoParent>> "[namespace current]::gotoParent %W \[%W getnode insert]; break"
    bind Outline <<ToggleMagicButton>> "[namespace current]::toggleMagicButton \[%W textcmd] [namespace current]::getCurTextFieldRange"
    bind Outline <<SearchForward>> "::incrsearch::enterSearchMode %W"
    foreach event [bind Outline] {
        bind Outline $event [string map {%% % %W {[winfo parent %W]}} [bind Outline $event]]
    }
}
bindCoreOutlineEvents 
}
