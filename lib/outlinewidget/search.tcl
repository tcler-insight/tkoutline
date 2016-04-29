namespace eval outlinewidget {
proc getNodeList {tree {afterNode ""}} {
    # Get a list of all the nodes in the tree
    set nodes ""
    $tree walk [$tree rootname] n {
        if {[$tree rootname] != "$n"} {
            lappend nodes $n
        }
    }
    if {[string length $afterNode] > 0} {
       set idx [lsearch $nodes $afterNode]
       if {$idx >= 0} {
          set nodes [concat [lrange $nodes [expr $idx + 1] end] [lrange $nodes 0 $idx]]
       }
    }
    return $nodes
 }
 proc findMatchingNode {tree string {afterNode ""}} {
    set nodes [getNodeList $tree $afterNode]
    set foundNode ""
    foreach node $nodes {
       if {[string match *${string}* [$tree set $node title]]} {
          set foundNode $node
          break
       }
    }
    return $foundNode
 }
 proc expandAllAncestors {tree node} {
    set parent [$tree parent $node]
    while {[string length $parent] > 0} {
       $tree set $parent expand 1
       set parent [$tree parent $parent]
    }
 }
proc searchOutline {outline string {direction forwards}} {
    # Start searching from the insertion cursor
    set node [$outline getnode insert]
    set index [$outline text search -$direction -elide $string insert [$outline getendidx $node]]
    if {[string length $index] == 0} {
        set match [findMatchingNode [$outline treecmd] $string $node]
        if {[string length $match] > 0} {
            # Ensure the matched node is visible
            expandAllAncestors [$outline treecmd] $match
            set index [$outline text search -elide $string [$outline getstartidx $match] [$outline getendidx $match]]
        } else {
            return ""
        }
    }
    $outline text mark set insert $index
    $outline text see insert
    $outline text tag remove sel 1.0 end
    $outline text tag add sel $index $index+[string length $string]c
    return $index
 }
}
