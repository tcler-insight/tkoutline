if {$tcl_version < 8.4} {
    # Snit makes use of namespace exists which is new to 8.4
    catch {rename namespace _namespace}
    proc namespace {args} {
        if {[lindex $args 0] == "exists"} {
            set ns [lindex $args 1]
            return [expr ![catch {namespace children ::$ns}]]
        } else {
            uplevel _namespace $args
        }
    }
}
# Curses Tk can be built with _Tcl_ 8.3 and 8.4, but it is based off of
# a _Tk_ version prior to 8.0.  As such, the text widget is missing the
# tag prevrange subcommand.  In addition, virtual events are not supported
if {[info exists ::ck_version]} {
namespace eval cktext {
proc tagPrevrange {win tag index} {
    set prevrange {}
    foreach {leftIdx rightIdx} [$win tag ranges $tag] {
        if {[$win compare $leftIdx >= $index]} {
            break
        } else {
            set prevrange [list $leftIdx $rightIdx]
        }
    }
    return $prevrange
}
# Add support for virtual events
proc tagBind {win tag sequence args} {
    # Is the given sequence a virtual event?
    if {[string match <<*>> $sequence]} {
        # Yes.  Convert it to a list of real events
        set result ""
        if {![info exists cktext::virtEvents($sequence)]} {
            error "Virtual event $sequence must be mapped to a key before binding"
        }

        # Bind each real event
        foreach sequence $cktext::virtEvents($sequence) {
            set result [eval $win tag bind $tag $sequence $args]
        }
        return $result
    } elseif {[lsearch {<Enter> <Leave>} $sequence] >= 0} {
        # Ck doesn't support mouse enter and leave events--ignore
        return ""
    } else {
        return [eval $win tag bind $tag $sequence $args]
    }
}
# Ck doesn't support the font option, so ignore it
proc tagConfigure {win tag args} {
    array set opts $args
    catch {unset opts(-font)}
    return [eval $win tag configure $tag [array get opts]]
}
proc mytext {win args} {
    if {([lindex $args 0] == "tag") && ([lindex $args 1] == "prevrange")} {
        return [eval tagPrevrange $win [lrange $args 2 end]]
    } elseif {([lindex $args 0] == "tag") && ([lindex $args 1] == "bind")} {
        return [eval tagBind $win [lrange $args 2 end]]
    } elseif {([lindex $args 0] == "tag") && ([lindex $args 1] == "configure")} {
        return [eval tagConfigure $win [lrange $args 2 end]]
    } else {
        return [eval $win $args]
    }
}
catch {rename ::text ::cktext::_text}
proc ::text {win args} {
    eval ::cktext::_text $win $args
    rename $win ctext::$win
    interp alias {} $win {} cktext::mytext ctext::$win
    return $win
}
}

# The font command doesn't exist in ck
proc font {measure font string} {
    return [string length $string]
}

# Rewrite bind so it supports virtual events
catch {rename bind cktext::bind}
proc bind {tag sequence args} {
    # Is the given sequence a virtual event?
    if {[string match <<*>> $sequence]} {
        # Yes.  Convert it to a list of real events
        set result ""
        if {![info exists cktext::virtEvents($sequence)]} {
            error "Virtual event $sequence must be mapped to a key before binding"
        }

        # Bind each real event
        foreach sequence $cktext::virtEvents($sequence) {
            set result [eval cktext::bind $tag $sequence $args]
        }
        return $result
    } else {
        return [eval cktext::bind $tag $sequence $args]
    }
}
    
proc event {subcmd virtual args} {
    switch $subcmd {
        add {
            set cktext::virtEvents($virtual) $args
        }
        info {
            return $cktext::virtEvents($virtual)
        }
        generate {
            set win $virtual
            set event [lindex $args 0]
            set script [bind $win [lindex $cktext::virtEvents($event) 0]]

            # Ugh what about percent substitution?
            uplevel #0 eval $script
        }
        default {
            error "$subcmd is an invalid subcommand"
        }
    }
    
}

catch {rename focus cktext::focus}
proc focus {args} {
    if {[lindex $args 0] == "-lastfor"} {
        return [cktext::focus]
    }
    return [eval cktext::focus $args]
}

}
