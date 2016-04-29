
#
# For use within a walk call.  Stops the descent on the current node
# but continues walking the rest of the nodes for a dfs search
#
proc ::struct::prune {} {
    return -code 5
}

# ::struct::tree::WalkCall --
#
#	Helper command to 'walk' handling the evaluation
#	of the user-specified command. Information about
#	the tree, node and current action are substituted
#	into the command before it evaluation.
#
# Arguments:
#	tree	Tree we are walking
#	node	Node we are at.
#	action	The current action.
#	cmd	The command to call, already partially substituted.
#
# Results:
#	None.

proc ::struct::tree::WalkCall {avar nvar tree node action cmd} {

    if {$avar != {}} {
	upvar 2 $avar a ; set a $action
    }
    upvar 2 $nvar n ; set n $node

    #set subs [list %n [list $node] %a [list $action] %t [list $tree] %% %]
    #set code [catch {uplevel 2 [string map $subs $cmd]} result]
    set code [catch {uplevel 2 $cmd} result]

    # decide what to do upon the return code:
    #
    #               0 - the body executed successfully
    #               1 - the body raised an error
    #               2 - the body invoked [return]
    #               3 - the body invoked [break]
    #               4 - the body invoked [continue]
    #               5 - the body invoked [struct::prune]
    # everything else - return and pass on the results
    #
    switch -exact -- $code {
	0 {}
	1 {
	    return -errorinfo [ErrorInfoAsCaller uplevel WalkCall]  \
		    -errorcode $::errorCode -code error $result
	}
	3 {
	    # FRINK: nocheck
	    return -code break
	}
	4 {}
    5 {
        # Force the rest of the current while loop iteration in the
        # caller to be skipped, resulting in a "prune" effect
        return -code continue
    }
	default {
	    upvar 1 rcode rcode rvalue rvalue
	    set rcode $code
	    set rvalue $result
	    return -code break
	    #return -code $code $result
	}
    }
    return {}
}

