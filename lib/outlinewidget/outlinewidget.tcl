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
source [file join [file dirname [info script]] compat.tcl]
source [file join [file dirname [info script]] treedisplay.tcl]
source [file join [file dirname [info script]] treeobserver.tcl]
source [file join [file dirname [info script]] treeops.tcl]
source [file join [file dirname [info script]] dnd.tcl]
source [file join [file dirname [info script]] search.tcl]
source [file join [file dirname [info script]] incrsearch.tcl]
package require XOTcllite
namespace eval outlinewidget {
namespace export outline
namespace import -force ::xotcllite::*
catch {Outline destroy}
Class create Outline
# The constructor
Outline instproc init1 {args} {
    # option defaults
    [self] set origTree ""
    [self] set useBulletImages 1
    [self] set wikimarkup [list wikilinks urls style]
    
    # Process the options
    foreach {option value} $args {
        switch -- $option {
            -tree {
                [self] set origTree $value
            }
            -useBulletImages -
            -wikimarkup {
                [self] set [string range $option 1 end] $value

                # I should figure out a better way to do this
                option add *[string range [[self] set text].$option 1 end] [[self] set $option] 
            }
            default {
                error "unknown option \"$option\""
            }
        }
    }
    [self] set text [::text [namespace tail [self].t]]
    pack [[self] set text] -fill both -expand 1

    # Insert the Outline bindings before the Text class bindings
    bindtags [my set text] [linsert [bindtags [my set text]] 1 Outline] 

    [self] _setTree [[self] set origTree]
}
Outline instproc _setTree {tree} {
    # The original, unwrapped tree
    [self] set origTree $tree

    # Start with a blank tree if none provided
    if {[string length [[self] set origTree]] == 0} {
        [self] set origTree [outlinewidget::getNewTree]
    }

    # Display the tree in the widget
    outlinewidget::initializeTreeDisplay [[self] set text] [[self] set origTree]

    # Wrap the tree so any tree modifications are automatically reflected in the display
    interp alias {} [self].tree {} outlinewidget::updateTreeDisplay [[self] set text] [[self] set origTree]
    [self] set tree [self].tree
    [[self] set text] tag bind bullet <<DragStart>> "::outlinewidget::dragStart [[self] set text] [[self] set tree] \[::outlinewidget::listitem::itemAtIdx [[self] set text] @%x,%y]"
    outlinewidget::configureOutlineBulletStateTags [self]
}
Outline instproc destroy {} {
    interp alias {} [[self] set tree] {}
    [[self] set origTree] destroy
    namespace delete ::[self]
}
# TODO: Add configure and cget methods
Outline instproc treecmd {} {
    [self] set tree
}
Outline instproc textcmd {} {
    [self] set text
}
Outline instproc tree {args} {
    eval outlinewidget::updateTreeDisplay [[self] set text] [[self] set origTree] $args
}
Outline instproc text {args} {
    eval [[self] set text] $args
}
Outline instproc getnode {textIdx} {
    return [outlinewidget::listitem::itemAtIdx [[self] set text] $textIdx]
}
Outline instproc getstartidx {node} {
    return [outlinewidget::listitem::index [[self] set text] $node.text.first]
}
Outline instproc getendidx {node} {
    return [outlinewidget::listitem::index [[self] set text] $node.text.last]
}
Outline instproc getnextvisiblenode {node} {
    return [outlinewidget::listitem::next [[self] set text] $node]
}
Outline instproc getprevvisiblenode {node} {
    return [outlinewidget::listitem::prev [[self] set text] $node]
}
Outline instproc selectnode {node} {
    return [outlinewidget::selectNodeText [[self] set text] $node]
}
Outline instproc search {string {direction forward}} {
    return [outlinewidget::searchOutline [self] $string $direction]
}
Outline instproc makepath args {
    set tree [my set tree]
    set n [eval ::outlinewidget::findOrInsertPath $tree [$tree rootname] end $args]
    my text mark set insert [my getendidx $n]
    my text see insert
    }


# Outline creator command
proc outline {win args} {
    frame $win
    rename $win outlinewidget::$win
    set obj ::$win
    Outline create $obj
    eval $obj init1 $args
    $obj set frame $win

    bind $win <Destroy> {
        %W destroy
    }
    return $win
}
}
package provide outlinewidget 0.1
