if 0 {
This code provides an interface to the [tdom] structure that is compatible with the API [http://tcllib.sourceforge.net/doc/tree.html] of [tcllib]'s struct::tree data structure.  Not all of [tcllib]'s methods are provided--only the ones I found most useful.  This code is not nearly as robust as the tcllib code.  The code requires tdom as well as the way-cool object oriented extension [xotcl].

The tdom interface is much more flexible than this interface which assumes that document elements are always created with a tag named "node".  With tdom any mix of tag names can be used in the tree and text nodes can be inserted as well.

Why?  I find the tcllib API pretty easy to work with (mostly because I've used it frequently) especially for playing around in the interpreter.  Although, it is much easier to create a dom by creating an xml file and then using dom parse.  The real reason I wrote this was so that I could play around with [xpath] searches in my [tkoutline] application. 

An extra method ''domDoc'' is provided to access the domDoc object.  This object behaves as documented in [tdom].  Also the node names in the tree are each domNode objects.

-[Brian Theado]

Sample session:
 % Tree mytree
 ::mytree

Insert some nodes
 % mytree insert root 0
 domNode4
 % mytree insert root 0
 domNode5
 % mytree insert root 0
 domNode6
 % mytree children root
 domNode6 domNode5 domNode4
 % mytree insert domNode4 0
 domNode7
 % mytree domDoc
 domDoc1
 % [mytree domDoc] documentElement
 domNode2

Perform an xpath query for all the leaves in the tree
 % [[mytree domDoc] documentElement] selectNodes {//*[count(child::*)=0]}
 domNode5 domNode6 domNode7

}
 # Partial wrapping of tDOM functionality with tcllib tree interface
 package require tdom
 package require XOTcl
 catch {namespace import xotcl::*}
 Class Tree

 # tkoutline depends on the tree name not to have any namespace separators
 # Newer versions of xotcl use the xotcl namespace for autonaming.  Override
 # that behavior here.
 Tree proc new args {
    eval [self] [[self] autoname Tree] $args
 }
 Tree instproc init {{existingDomDoc ""}} {
    [self] instvar domDoc
    if {[string length $existingDomDoc] == 0} {
        set domDoc [dom createDocument node]
    } else {
        set domDoc $existingDomDoc
    }
    [self] parametercmd domDoc
    next
 }
 Tree instproc insertNode {parent idx child} {

    # tcllib tree indexing starts at zero, but DOM starts at one
    incr idx
    set sibling [$parent child $idx]
    if {[string length $sibling] == 0} {
        return [$parent appendChild $child]
    } else {
        return [$parent insertBefore $child $sibling]
    }
 }

 # tcllib tree allows an optional third argument to specify the
 # name of the node.  tDOM doens't allow node names to be specified
 # The easy way out--don't allow the third argument 
 Tree instproc insert {parent idx} {
    [self] instvar domDoc

    # Create the node
    set newNode [$domDoc createElement node]
    
    # Add the node to the tree
    [self] insertNode $parent $idx $newNode
 }
 Tree instproc move {newParent idx nodeToMove args} {
    foreach node [concat $nodeToMove $args] {
        set oldParent [$node parentNode]
        $oldParent removeChild $node
        [self] insertNode $newParent $idx $node
        incr idx
    }
 }
 Tree instproc keyexists {node -key key} {
    $node hasAttribute $key
 }
 Tree instproc keys {node} {
    $node attributes
 }
 Tree instproc depth {node} {
    return [llength [$node ancestor all]]
 }
 # This doesn't work as I expect (multiple levels of descendants don't seem to get counted)
 Tree instproc size {node} {
    return [llength [$node descendant all]]
 }
 Tree instproc size {node} {
    return [llength [$node selectNodes descendant::*]]
 }
 Tree instproc isleaf {node} {
    return [expr [llength [$node descendant all]] == 0]
 }
 
 # This seems correct, but isn't giving me what I expect
 Tree instproc index {node} {
    return [llength [$node psibling all]]
 }

 # Try this instead
 Tree instproc index {node} {
    return [lsearch [[self] children [[self] parent $node]] $node]
 }

 Tree instproc numchildren {node} {
    return [llength [$node child all]]
 }

 Tree instproc set {node args} {
    switch [llength $args] {
        0 {
            $node getAttribute data
        }
        1 {
            $node setAttribute data [lindex $args 0]
            $node getAttribute data
        }
        2 {
            $node getAttribute [lindex $args 1]
        }
        3 {
            set switch [lindex $args 0]
            set key [lindex $args 1]
            set value [lindex $args 2]
            $node setAttribute $key $value
            $node getAttribute $key
        }
        default {error "wrong number of arguments"}
    }
 }

 # Dynamically construct the simple command that have only a node argument
 foreach {treeCmd domCmd} {children childNodes parent parentNode previous previousSibling next nextSibling delete delete} {
    Tree instproc $treeCmd {node} "\$node $domCmd"
 }
 Tree instproc destroy {args} {
    [self] instvar domDoc
    $domDoc delete
    next
 }

 # The tcllib interface always names the root node "root"
 # tDOM doesn't have a way to specify node names.  Therefore,
 # install this filter to automatically convert "root" to the
 # actual root element
 Tree instproc convertRoot {node args} {
    [self] instvar domDoc

    # Convert input node from name "root"
    if {$node == "root"} {
        set node [$domDoc documentElement]
    }

    # Dispatch the method
    set retVal [eval next $node $args]

    # Convert output node to name "root"
    if {$retVal == [$domDoc documentElement]} {
        return root
    } else {
        return $retVal
    }
 }
 Tree instfilter convertRoot

 # Only call the filter for methods that have node as a first argument
 Tree instfilterguard convertRoot {
    ([lsearch {init destroy} [self calledproc]] < 0) &&
        ([lsearch [Tree info instcommands] [self calledproc]] >= 0)
 }
 package provide tdomtree 0.1
