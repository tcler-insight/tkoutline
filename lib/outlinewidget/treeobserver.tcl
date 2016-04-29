# treeobserver.tcl - Observe tree operations and update display
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
# Overrides the definition in treedisplay.tcl
proc saveNodeToTree {win tree node} {
    updateTreeDisplay $win $tree _set $node title [getNodeText $win $node]
}
proc ensureOneNodeIsVisible {win tree} {
    if {[$tree numchildren root] == 0} {
        set node [updateTreeDisplay $win $tree insert root 0]
        updateTreeDisplay $win $tree set $node title ""
    }
}
proc updateTreeDisplay {win tree args} {
    set subcmd [lindex $args 0]
    set node [lindex $args 1]
    switch $subcmd {
        cut {
            set cursorInfo [getCursorInfo $win insert]
            # Get visible descendents
            set dedentNodes [getDisplayableDescendents $tree $node]

            set parent [$tree parent $node]

            set retVal [eval $tree $args] 

            redrawNodeOrAncestor $win $tree $parent
            if {[listitem::exists $win $node]} {
                listitem::delete $win $node
            }
            foreach node $dedentNodes {
                redrawNode $win $tree $node
            }

            # Delete node, but ensure a node is visible
            ensureOneNodeIsVisible $win $tree 

            restoreInsertionCursor $win $cursorInfo
            return $retVal
        }
        move {
            set cursorInfo [getCursorInfo $win insert]
            set targetParent [lindex $args 1]
            set movingNodes [lrange $args 3 end]
            foreach movingNode $movingNodes {
                # List of parents that may need their prefixes and suffixes redrawn
                lappend srcParents [$tree parent $movingNode]

                # List of visible descendants that will need redrawing
                lappend lastVisibles [getLastVisibleDescendent $tree $movingNode]
            }
            set wasTargetALeaf [$tree isleaf $targetParent]
            set retVal [eval $tree $args]
            foreach movingNode $movingNodes lastVisible $lastVisibles {
                if {[listitem::exists $win $movingNode]} {
                    listitem::delete $win $movingNode $lastVisible
                }
                if {$wasTargetALeaf} {
                    $tree set $targetParent expand 1
                    redrawNodeOrAncestor $win $tree $targetParent
                }
                if {[$tree set $targetParent expand]} {
                    showNode $win $tree $movingNode
                    showDescendents $win $tree $movingNode
                }
            }
            foreach parent [concat $targetParent $srcParents] {
                if {[$tree numchildren $parent] == 0} {
                    #updateTreeDisplay $win $tree set $parent -key expand 0
                    $tree set $parent expand 0
                    redrawNodeOrAncestor $win $tree $parent
                }
            }
            restoreInsertionCursor $win $cursorInfo
            return $retVal
        }
        delete {
            set cursorInfo [getCursorInfo $win insert]
            foreach deleteNode $node {
                # List of parents that may need their prefixes and suffixes redrawn
                lappend srcParents [$tree parent $deleteNode]

                # List of visible descendants that will need redrawing
                lappend lastVisibles [getLastVisibleDescendent $tree $deleteNode]
            }
            set retVal [eval $tree $args]
            foreach deleteNode $node lastVisible $lastVisibles {
                if {[listitem::exists $win $deleteNode]} {
                    listitem::delete $win $deleteNode $lastVisible
                }
            }
            foreach parent $srcParents {
                if {[$tree numchildren $parent] == 0} {
                    #updateTreeDisplay $win $tree set $parent -key expand 0
                    $tree set $parent expand 0
                    if {$parent != [$tree rootname]} {
                    redrawNode $win $tree $parent
                    }
                } else {
                    redrawNodeOrAncestor $win $tree $parent
                }
            }
            ensureOneNodeIsVisible $win $tree 
            restoreInsertionCursor $win $cursorInfo
            return $retVal
        }
        insert {
            set cursorInfo [getCursorInfo $win insert]
            set targetParent [lindex $args 1]
            set toggleParent [expr [$tree numchildren $targetParent] == 0]
            set retVal [eval $tree $args]
            foreach node $retVal {
                if {[$tree index $node] > 0} {
                    if {[$tree keyexists [$tree previous $node] nobullet]} {
                        $tree set $node nobullet ""
                    }
                }
                if {![$tree keyexists $node nobullet]} {
                    $tree set $node title $node    
                } else {
                    $tree set $node title ""
                }
                $tree set $node expand 0
                showNode $win $tree $node
            }
            if {$toggleParent} {
                $tree set $targetParent expand 1
                if {$targetParent != [$tree rootname]} {
                    redrawNode $win $tree $targetParent
                }
            }
            restoreInsertionCursor $win $cursorInfo
            return $retVal
        }
        _set {
            # Backdoor to bypass the display update (for avoiding circular updates)
            return [eval $tree set [lrange $args 1 end]]
        }
        set {
            # Change the node title
            if {[llength $args] == 4} {
                switch [lindex $args 2] {
                    title {
                        set cursorInfo [getCursorInfo $win insert]
                        set retVal [eval $tree $args]
                        if {[listitem::exists $win $node]} {
                            listitem::setField $win $node text $retVal
                        }
                        restoreInsertionCursor $win $cursorInfo
                        return $retVal
                    }
                    expand {
                        set cursorInfo [getCursorInfo $win insert]
                        if {[$tree keyexists $node expand]} {
                            set origValue [$tree set $node expand]
                            set newValue [lindex $args 3]
                            if {($newValue != $origValue) && !$newValue} {
                                if {[listitem::exists $win $node]} {
                                    set last [getLastVisibleDescendent $tree $node]
                                }
                            }
                        }
                        set retVal [eval $tree $args]
                        if {$retVal != $origValue} {
                            if {[listitem::exists $win $node]} {
                                redrawNode $win $tree $node
                                if {$retVal} {
                                    showDescendents $win $tree $node
                                } else {
                                    #hideDescendents $win $tree $node
                                    listitem::delete $win [listitem::next $win $node] $last
                                }
                            }
                        }
                        restoreInsertionCursor $win $cursorInfo
                        return $retVal
                    }
                    nobullet - buttoncmd - extratags {
                        set retVal [eval $tree $args]
                        #setNodeState $win $tree $node
                        redrawNode $win $tree $node
                    }
                }
            }
        }
        unset {
            switch [lindex $args 2] {
                nobullet - buttoncmd {
                    set retVal [eval $tree $args]
                    redrawNode $win $tree $node
                }
            }
        }
    }
    set retVal [uplevel $tree $args]
    return $retVal

}
namespace eval treeobserver {}
proc initTreeObservation {win tree} {
    interp alias {} treeobserver::$tree {} outlinewidget::updateTreeDisplay $win $tree
    return treeobserver::$tree
}
}
