
namespace eval outlinewidget {
proc dragStart {win tree node} {
    $win configure -cursor hand1

    # Initialize the motion and stop events
    $win tag bind bullet <<DragMotion>> "[namespace current]::dragMotion $win $tree $node $node @%x,%y"
    $win tag bind bullet <<DragStop>> "[namespace current]::dragStop $win $tree $node $node @%x,%y"

    # While dragging, disable text selecting
    bind $win <B1-Motion> "break"    
}
proc dragMotion {win tree dragNode lastNode idx} {
    set n [listitem::itemAtIdx $win $idx]

    # Is the motion on a new node?
    if {([string compare $n $lastNode] != 0) && ([string length $lastNode] > 0)} {
        # Yes. Generate a leave event on the old node
        dragLeave $win $lastNode
    }

    # Re-bind the Motion event to have the latest "lastNode"
    $win tag bind bullet <<DragMotion>> [list [namespace current]::dragMotion $win $tree $dragNode $n @%x,%y]
    $win tag bind bullet <<DragStop>> [list [namespace current]::dragStop $win $tree $dragNode $n @%x,%y]

    # Is the motion on a node?
    if {[string length $n] > 0} {
        # Yes.  Generate a dragover event
        dragOver $win $n
    }
    if {[string compare $n $dragNode] != 0}  {
        $win configure -cursor hand2
    } else {
        $win configure -cursor hand1
    }    
}
proc dragStop {win tree dragNode lastNode idx} {
    set n [listitem::itemAtIdx $win $idx]
    if {[string length $n] > 0} {
        # Is the drag target the same as the node that was being dragged?
        if {[string compare $n $dragNode] != 0}  {
            # No. Generate the drop event
            dragLeave $win $lastNode
            dragDrop $win $tree $dragNode $lastNode
        } else {
            # Yes.  Treat it like a click
            dragLeave $win $n
            #event generate $win <<Click>>
        }
    }
    $win configure -cursor {}

    # Now that dragging is complete, re-enable text selection
    bind $win <B1-Motion> ""
}
proc dragOver {win node} {
    $win tag configure draghighlight -foreground orange
    $win tag add draghighlight item:$node.first item:$node.last
    $win tag raise draghighlight
#    $win tag configure node:$node -foreground orange
}
proc dragLeave {win node} {
    $win tag remove draghighlight item:$node.first item:$node.last
#    $win tag configure node:$node -foreground black
    $win configure -cursor {}
}
proc dragDrop {win tree dragNode dropNode} {
    if {![isNodeDescendentOf $tree $dropNode $dragNode]} {
        moveNodeBefore $tree $dragNode $dropNode
    }
}
}
