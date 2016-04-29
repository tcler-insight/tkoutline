# Tkoutline - an outline editor.
# Copyright (C) 2002  Brian P. Theado
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
option add *Text.bulletFont "Courier 8" widget
option add *Text.indentString "   " widget
option add *Text.useBulletImages 0 widget

# By default, disable wikimarkup
option add *Text.wikimarkup "" widget

# Prevents the cursor from being placed on text tagged as readonly
# Also prevents deletion of text marked readonly
source [file join [file dirname [info script]] textprotect.tcl]
source [file join [file dirname [info script]] listitem.tcl]

# For marking portions of the text as modified
package require wcb

# Returns a list of descendendents of the given node in the given
# tree that should be visible.  The order of the list is the order
# the nodes should be displayed
proc getDisplayableDescendents {tree node} {
    set descendents {}
    if {[$tree set $node expand]} {
        foreach child [$tree children $node] {
            lappend descendents $child 
            eval lappend descendents [getDisplayableDescendents $tree $child]
        }
    } 
    return $descendents
}

# Should only be called for a visible node
proc getLastVisibleDescendent {tree node} {
    set lastChild $node
    while {![$tree isleaf $lastChild] && [$tree set $lastChild expand]} {
	set lastChild [lindex [$tree children $lastChild] end]
    }
    return $lastChild
}

# Returns the index where the given node should be inserted
proc getNodeIdx {win tree node} {
    set prev [$tree previous $node]
    if {[string length $prev] == 0} {
        set parent [$tree parent $node]
        if {[string compare $parent [$tree rootname]] == 0} {
            set idx 0.0
        } else {
            set idx [listitem::index $win $parent.last]
        }
    } else {
        set idx [listitem::index $win [getLastVisibleDescendent $tree $prev].last]
    }
    return $idx
}
proc minIdx {list} {
    return [lindex [lsort -unique -dictionary $list] 0]
}

# Finds the node following the given node that has a depth less than or 
# equal to the given depth
proc findNextShallowerNode {win startIdx depth} {
    set indices {}
    if {[lsearch [$win tag names $startIdx] level$depth] >= 0} {
        set indices [$win index $startIdx]
        incr depth -1
    }
    for {set x $depth} {$x > 0} {incr x -1} {
        set nextRange [$win tag nextrange level$x $startIdx]
        set indices [concat $indices [lindex $nextRange 0]]
    }
    if {[llength $indices] > 0} {
        return [minIdx $indices]
    } else {
        return end-1c
    }
}
proc isNodeDescendentOf {tree possibleDescendent node} {
    set parent [$tree parent $possibleDescendent]
    while {[string length $parent] > 0} {
	if {[string compare $parent $node] == 0} {return 1}
	set parent [$tree parent $parent]
    }
    return 0
}
proc isIdxInNodeText {win idx} {
    return [listitem::isIdxInField $win text $idx]
}
proc getNodeTextStartIdx {win node} {
    return [listitem::index $win $node.text.first]
}
proc getNodeText {win node} {
    return [listitem::getField $win $node text]
}
proc configureBulletStateTags {win tree} {
    $win tag bind leaf <<Click>> ""
    $win tag bind collapsed <<Click>> "[namespace current]::expandNode $win $tree \[[namespace current]::listitem::itemAtIdx $win @%x,%y]"
    $win tag bind expanded <<Click>> "[namespace current]::collapseNode $win $tree \[[namespace current]::listitem::itemAtIdx $win @%x,%y]"
}
proc configureBulletTags {win tree} {
    configureBulletStateTags $win $tree
    $win tag configure bullet -font [option get $win bulletFont Text]
    $win tag configure indent -font [option get $win bulletFont Text]
    $win tag bind bullet <Enter> "$win configure -cursor \"\""
    $win tag bind bullet <Leave> "$win configure -cursor xterm"
}
proc configureButtonTag {win tree} {
    package require markup
    $win tag configure button -foreground purple
    $win tag configure cursoredbutton -foreground red
    ::markup::flashTag $win button cursoredbutton
    $win tag bind button <Enter> "+$win configure -cursor hand2"
    $win tag bind button <Leave> "+$win configure -cursor xterm"
    $win tag bind button <Button> "[namespace current]::evalDescendentsAsScript $tree \[[namespace current]::listitem::itemAtIdx $win @%x,%y]"
}
proc getCurTextFieldRange win {
    set idx insert
    set curNode [[namespace current]::listitem::itemAtIdx $win $idx]
    return [list [[namespace current]::listitem::index $win $curNode.text.first] \
                 [[namespace current]::listitem::index $win $curNode.text.last]]
}
proc toggleMagicButton {win rangeCmd} {
    set ranges [$win tag ranges sel]
    if {[llength $ranges] == 0} {
        set ranges [eval [concat $rangeCmd $win]]
    } else {
        set ranges [list sel.first sel.last]
    }
    foreach {start end} $ranges {
        if {[doesRangeContainTag $win $start $end button]} {
            set left [$win search -backward -elide {[%} $end $start]
            set right [$win search -forwards -elide {%]} $start $end]
            $win delete $right $right+2c
            $win delete $left $left+2c
        } else {
            $win insert $end {%]} [$win tag names $end-1c]
            $win insert $start {[%} [$win tag names $start]
        }
    }
}
proc getFirstVisibleAncestor {win tree node} {
    if {$node != [$tree rootname]} {
        set parent [$tree parent $node]
        while {(![listitem::exists $win $parent]) && ($parent != [$tree rootname])} {
            set parent [$tree parent $parent]
        }
        if {$parent != [$tree rootname]} {
            return $parent
        } else {
            return ""
        }
    } else {
        return ""
    }
}
proc getImagePadding {win image} {
    set imgWidth [image width $image]
    set indentString [option get $win indentString Text]
    set strWidth [font measure [option get $win bulletFont Text] $indentString]
    if {$strWidth > $imgWidth} {
        return [expr ($strWidth - $imgWidth) / 2]
    } else {
        return 0
    }
}
proc showBulletImage {state win startIdx endIdx} {
    variable bullets
    if {[lsearch [$win tag names $startIdx+1c] bullet] >= 0} {
        # Insert the image
        $win image create $endIdx -image "$bullets($state)" -padx [getImagePadding $win $bullets($state)]

        # Remove the text version of the bullet
        $win tag remove readonly $startIdx $endIdx+1c
        $win delete $startIdx $endIdx
        $win tag add readonly $startIdx
    }
}
variable bulletDir [file join [pwd] [file dirname [info script]]]
proc initializeBulletImages {} {
    variable bullets 
    variable bulletDir
    if {![info exists bullets]} {
        foreach state {expand collapse leaf} {
            set bullets($state) [image create photo -file [file join $bulletDir $state.gif]]
        }
    }
}
proc initializeTreeDisplay {win tree} {
    $win configure -state normal -tabs [font measure [option get $win bulletFont Text] "   "]
    set wikimarkup [option get $win wikimarkup Text]
    if {[string length $wikimarkup] > 0} {
        package require wikimarkup
        wikimarkup::addWikiRules $win $wikimarkup
        }
    set useBulletImages [option get $win useBulletImages Text]
    if {$useBulletImages} {
        initializeBulletImages
    }
    configureButtonTag $win $tree

    setTreeForDisplay $win $tree
    setWidgetProtections $win
    $win mark set insert 0.0
}
proc setTreeForDisplay {win tree} {
    showTree $win $tree
    watchForModifiedText $win $tree
    #$win tag configure modified -background yellow
    configureBulletTags $win $tree
    $win tag configure hiddenspace -elide 1
}
proc replaceListElement {list pattern replacement} {
    set idx [lsearch $list $pattern]
    if {$idx >= 0} {
        return [lreplace $list $idx $idx $replacement]
    } else {
        return [lappend list $replacement]
    }
}
proc replaceCallback {win when what script} {
    set pattern [lindex $script 0]*
    eval wcb::callback $win $when $what [replaceListElement [wcb::callback $win $when $what] $pattern $script]
}

# All text that has changed in the text widget, but hasn't been saved
# to the tree is tagged with "modified"
proc markModifiedText {tree win idx args} {
    # Remove the underscore from the window name
    set win [string range [namespace tail $win] 1 end]
    if {[isIdxInNodeText $win $idx]} {
        $win tag add modified "$idx linestart" "$idx lineend"
        after idle "[namespace current]::saveChangedTextToTree $win $tree"
    }
}
proc watchForModifiedText {win tree} {
    replaceCallback $win before insert "[namespace current]::markModifiedText $tree"
    replaceCallback $win before delete "[namespace current]::markModifiedText $tree"
}

proc nodeBulletToText {tree node} {
    if {![$tree isleaf $node] || [$tree keyexists $node openCmd]} {
        if {[$tree set $node expand]} {
            set bullet {[-]}
            set stateTags {expanded expandtext}
        } else {
            set bullet {[+]}
            set stateTags {collapsed collapsetext}
        }
    } else {
        set bullet " * "
        set stateTags {leaf leaftext}
    }
    if {[$tree keyexists $node nobullet]} {
        set bullet ""
    }
    set bullet [list "$bullet" $stateTags]
    return $bullet
}

proc nodeSuffixToText {tree node} {
    if {![$tree isleaf $node]} {
        if {[$tree set $node expand]} {
            # Should be an empty string.  See comment below for explanation
            set suffix [list " " hiddenspace]
        } else {
            set suffix [list "([$tree size $node])" {}]
        }
    } else {
        # Should be empty string, but this is a kludge to get around the
        # problem where if the end key is hit twice, the cursor moves to
        # the next line (because textprotect.tcl can't distinguish between
        # the right arrow at the end of a line and hitting the end key
        # at the end of the line).
        set suffix [list " " hiddenspace]
    }
    return $suffix
}

# Returns a list of text/tag pairs suitable as arguments to text
# widget insertion
proc nodeToText {tree node indentString} {
    # Construct the strings with their element specific tags
    set depth [$tree depth $node]
    
    set elems(bullet) [nodeBulletToText $tree $node]
    set textTags ""
    if {[$tree keyexists $node buttoncmd]} {
        set textTags button
    }
    set elems(text) [list [$tree set $node title] $textTags]
    set elems(suffix) [nodeSuffixToText $tree $node]
    set extraTags [list * level$depth {bullet suffix} readonly]
    if {[$tree keyexists $node extratags]} {
        lappend extraTags * [$tree set $node extratags]
    }
    
    # If the tree text is empty the readonly tags will merge together
    # preventing the cursor to be placed on the node.  The separator
    # tag allows the cursor to be placed.
    if {[string length [lindex $elems(text) 0]] == 0} {
        lappend extraTags text separator
    }
    set fields [list bullet $elems(bullet) text $elems(text) suffix $elems(suffix)]

    return [list $fields $extraTags] 
}
proc replaceBulletTextWithImages win {
    foreach bulletType {leaf expand collapse} {
        foreach {first last} [$win tag ranges ${bulletType}text] {
            ::outlinewidget::showBulletImage $bulletType $win $first $last-1c
        }
        $win tag remove ${bulletType}text 1.0 end 
    }
}
proc showNodes {win tree nodes {idx {}}} {
    if {[string length $idx] == 0} {
        set idx [getNodeIdx $win $tree [lindex $nodes 0]]
    }
    set nodesText {}
    foreach node $nodes {
        eval lappend nodesText $node [nodeToText $tree $node [option get $win indentString Text]]
        }
    eval listitem::insert $win $idx $nodesText
    set useBulletImages [option get $win useBulletImages Text]
    if {$useBulletImages} {
        # Disable syntax highlighting while the bullets are being inserted
        markup::suspend $win
        replaceBulletTextWithImages $win
        markup::resume $win
    }
    foreach node $nodes {setNodeMargins $win $tree $node}
}
proc showNode {win tree node {idx ""}} {showNodes $win $tree $node $idx}
proc showDescendents {win tree node} {
    set nodes [getDisplayableDescendents $tree $node]
    if {[llength $nodes] > 0} {showNodes $win $tree $nodes}
}

proc showTree {win tree} {
    # The root node must be expanded in order for this to work
    $tree set [$tree rootname] expand 1
    showDescendents $win $tree [$tree rootname]
}

proc hideNode {win tree node} {
    if {[string compare $node [$tree rootname]] != 0} {
        saveChangedTextToTree $win $tree
        listitem::delete $win $node
    }
}
proc redrawNode {win tree node} {
    set idx [listitem::index $win $node.first]
    hideNode $win $tree $node
    showNode $win $tree $node $idx
}
proc redrawNodeOrAncestor {win tree node} {
    while {![listitem::exists $win $node] && ($node != [$tree rootname])} {
        set node [$tree parent $node]
    }
    if {$node != [$tree rootname]} {
        redrawNode $win $tree $node
    }
}

proc saveNodeToTree {win tree node} {
    $tree set $node title [getNodeText $win $node]
}

proc saveChangedTextToTree {win tree} {
    foreach {startIdx endIdx} [$win tag ranges modified] {
        saveNodeToTree $win $tree [listitem::itemAtIdx $win $startIdx]
        $win tag remove modified $startIdx $endIdx
    }
}

proc hideDescendents {win tree node} {
    if {[$tree numchildren $node] > 0} {
        set firstChild [lindex [$tree children $node] 0]
        set lastNode [getLastVisibleDescendent $tree $node]
        saveChangedTextToTree $win $tree
        listitem::delete $win $firstChild $lastNode
    }
    return
}
proc setNodeMargins {win tree node} {
    set margin1 [expr ([$tree depth $node] - 1) * [font measure [option get $win bulletFont Text] [option get $win indentString Text]]]
    if {[$tree keyexists $node nobullet]} {
        set margin2 [expr $margin1 + [font measure [option get $win bulletFont Text] " "]]
    } else {
        set margin2 [expr $margin1 + [font measure [option get $win bulletFont Text] "[option get $win indentString Text] "]]
    }
    $win tag configure item:$node -lmargin1 $margin1
    $win tag configure item:$node -lmargin2 $margin2
}


# Returns the node the given index is on and the number of characters
# within that node's text the index is offset.  It also returns
# a boolean indicating whether or not the given index is currently
# visible
proc getCursorInfo {win index} {
   set node [listitem::itemAtIdx $win $index]
   if {[string length $node] > 0} {
       scan [$win index $index] %d.%d line insertChar
       scan [$win index [getNodeTextStartIdx $win $node]] %d.%d line startChar
       set offset [expr $insertChar - $startChar]
   } else {
        set offset ""
   }
   set isCursorVisible [expr [llength [$win bbox $index]] > 0]
   return [list $node $offset $isCursorVisible]
}
proc restoreInsertionCursor {win cursorInfo} {
    set node [lindex $cursorInfo 0]
    set offset [lindex $cursorInfo 1]
    set wasCursorVisible [lindex $cursorInfo 2]
    if {[listitem::exists $win $node]} {
        $win mark set insert [getNodeTextStartIdx $win $node]+${offset}c
    }
    if {$wasCursorVisible} {
        $win see insert
    }
}

proc setNodeState {win tree node} {
    listitem::untagItem $win $node readonly
    listitem::setField $win $node bullet [nodeBulletToText $tree $node]
    listitem::tagField $win $node bullet readonly
    listitem::setField $win $node suffix [nodeSuffixToText $tree $node]
    listitem::tagField $win $node suffix readonly
}
proc setNodeExpanded {win tree node} {
    $tree set $node expand 1
    setNodeState $win $tree $node
}
proc setNodeCollapsed {win tree node} {
    $tree set $node expand 0
    setNodeState $win $tree $node
}
proc setNodeAsLeaf {win tree node} {
    $tree set $node expand 0
    setNodeState $win $tree $node
}

}
